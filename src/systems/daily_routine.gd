## An NPC's daily routine: a fixed sequence of activity blocks (work, home,
## pub, sleep, ...) covering the 24-hour cycle, e.g. "práce → domů → hospoda
## → spánek". Purely a schedule lookup — the world simulation (later
## milestones) is responsible for actually moving the NPC and animating the
## current activity.
class_name DailyRoutine
extends RefCounted

const UNSCHEDULED := "unscheduled"

## Each entry: {"state": String, "start_hour": int, "end_hour": int}.
## start_hour/end_hour are in [0, 24). A block wraps past midnight when
## end_hour <= start_hour, e.g. sleep 22 -> 6.
var _blocks: Array[Dictionary] = []


## Appends an activity block. Hours outside [0, 23] are rejected (pushed
## calls are simply ignored) to keep a routine internally consistent.
func add_block(state: String, start_hour: int, end_hour: int) -> void:
	if start_hour < 0 or start_hour > 23 or end_hour < 0 or end_hour > 23:
		push_error("DailyRoutine.add_block: hours must be within 0-23, got %d-%d" % [start_hour, end_hour])
		return
	_blocks.append({"state": state, "start_hour": start_hour, "end_hour": end_hour})


func get_blocks() -> Array[Dictionary]:
	return _blocks.duplicate(true)


## Returns the activity state scheduled for the given hour (0-23), or
## UNSCHEDULED if no block covers it.
func get_state_for_hour(hour: int) -> String:
	var h: int = ((hour % 24) + 24) % 24
	for block: Dictionary in _blocks:
		var start: int = block["start_hour"]
		var end: int = block["end_hour"]
		if start == end:
			continue
		var in_block: bool = (h >= start and h < end) if start < end else (h >= start or h < end)
		if in_block:
			return block["state"]
	return UNSCHEDULED


## True when every hour of the day resolves to a scheduled state, i.e. the
## blocks added so far fully cover the 24-hour cycle with no gaps.
func covers_full_day() -> bool:
	for hour in range(24):
		if get_state_for_hour(hour) == UNSCHEDULED:
			return false
	return true


## A common "work -> home -> pub -> sleep" template.
static func worker_routine() -> DailyRoutine:
	var routine := DailyRoutine.new()
	routine.add_block("work", 8, 16)
	routine.add_block("home", 16, 20)
	routine.add_block("pub", 20, 22)
	routine.add_block("sleep", 22, 8)
	return routine


## A routine for NPCs without a fixed job: home during the day, out and
## about in the evening, sleeping at night.
static func idle_routine() -> DailyRoutine:
	var routine := DailyRoutine.new()
	routine.add_block("home", 9, 18)
	routine.add_block("pub", 18, 23)
	routine.add_block("sleep", 23, 9)
	return routine


## A night-shift routine: sleeps during the day, works overnight.
static func night_shift_routine() -> DailyRoutine:
	var routine := DailyRoutine.new()
	routine.add_block("sleep", 7, 15)
	routine.add_block("home", 15, 19)
	routine.add_block("work", 19, 7)
	return routine
