## An NPC's criminal record — the accumulated history of past interactions
## with police. Grows only through add_entry(); nothing in this class rolls
## dice or decides sanctions, it purely stores and summarizes what already
## happened so LawEngine (recidivist sanction tiers, fine multipliers) and
## NPCPersonality (flee/resist odds) can read from it.
class_name CriminalRecord
extends RefCounted

var _entries: Array[Dictionary] = []


## Records one closed interaction. `offense_type` is optional context (one
## of LawEngine's offense types) used for type-level statistics; pass "" if
## unknown. `imprisonment_days` is 0 when the sanction was not imprisonment.
func add_entry(offense_id: String, sanction_code: String, zone: String, day: int, offense_type: String = "", imprisonment_days: int = 0, warning_only: bool = false) -> void:
	_entries.append({
		"offense_id": offense_id,
		"sanction_code": sanction_code,
		"zone": zone,
		"day": day,
		"offense_type": offense_type,
		"imprisonment_days": imprisonment_days,
		"warning_only": warning_only,
	})


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func get_total_priors() -> int:
	return _entries.size()


func get_prior_count(offense_id: String) -> int:
	var count := 0
	for entry: Dictionary in _entries:
		if entry["offense_id"] == offense_id:
			count += 1
	return count


func get_prior_count_by_type(offense_type: String) -> int:
	var count := 0
	for entry: Dictionary in _entries:
		if entry["offense_type"] == offense_type:
			count += 1
	return count


func has_been_imprisoned() -> bool:
	return get_imprisonment_count() > 0


func get_imprisonment_count() -> int:
	var count := 0
	for entry: Dictionary in _entries:
		if int(entry.get("imprisonment_days", 0)) > 0:
			count += 1
	return count


## Builds the {"priors_by_offense": {...}} shape LawEngine.get_prior_count()
## and LawEngine.get_sanctions_for_offense() expect as an npc_record.
func to_npc_record() -> Dictionary:
	var priors_by_offense: Dictionary = {}
	for entry: Dictionary in _entries:
		var offense_id: String = entry["offense_id"]
		priors_by_offense[offense_id] = int(priors_by_offense.get(offense_id, 0)) + 1
	return {"priors_by_offense": priors_by_offense}
