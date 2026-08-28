## Unit tests for src/systems/daily_routine.gd.
extends TestCase


func test_empty_routine_is_fully_unscheduled() -> void:
	var routine := DailyRoutine.new()
	assert_eq(routine.get_state_for_hour(10), DailyRoutine.UNSCHEDULED)
	assert_false(routine.covers_full_day())


func test_simple_block_lookup() -> void:
	var routine := DailyRoutine.new()
	routine.add_block("work", 8, 16)
	assert_eq(routine.get_state_for_hour(8), "work")
	assert_eq(routine.get_state_for_hour(15), "work")
	assert_eq(routine.get_state_for_hour(16), DailyRoutine.UNSCHEDULED)
	assert_eq(routine.get_state_for_hour(7), DailyRoutine.UNSCHEDULED)


func test_wraparound_block_across_midnight() -> void:
	var routine := DailyRoutine.new()
	routine.add_block("sleep", 22, 6)
	assert_eq(routine.get_state_for_hour(23), "sleep")
	assert_eq(routine.get_state_for_hour(0), "sleep")
	assert_eq(routine.get_state_for_hour(5), "sleep")
	assert_eq(routine.get_state_for_hour(6), DailyRoutine.UNSCHEDULED)
	assert_eq(routine.get_state_for_hour(21), DailyRoutine.UNSCHEDULED)


func test_get_state_for_hour_normalizes_out_of_range_hours() -> void:
	var routine := DailyRoutine.new()
	routine.add_block("work", 8, 16)
	assert_eq(routine.get_state_for_hour(32), "work")


func test_worker_routine_covers_full_day() -> void:
	var routine := DailyRoutine.worker_routine()
	assert_true(routine.covers_full_day())
	assert_eq(routine.get_state_for_hour(10), "work")
	assert_eq(routine.get_state_for_hour(18), "home")
	assert_eq(routine.get_state_for_hour(21), "pub")
	assert_eq(routine.get_state_for_hour(2), "sleep")


func test_idle_routine_covers_full_day() -> void:
	assert_true(DailyRoutine.idle_routine().covers_full_day())


func test_night_shift_routine_covers_full_day() -> void:
	var routine := DailyRoutine.night_shift_routine()
	assert_true(routine.covers_full_day())
	assert_eq(routine.get_state_for_hour(23), "work")
	assert_eq(routine.get_state_for_hour(10), "sleep")


func test_add_block_rejects_out_of_range_hours() -> void:
	var routine := DailyRoutine.new()
	routine.add_block("work", -1, 5)
	routine.add_block("work", 5, 25)
	assert_eq(routine.get_blocks().size(), 0, "invalid blocks must not be recorded")
