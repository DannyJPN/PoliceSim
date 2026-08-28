## A single NPC: stable identity, hidden personality, accumulated criminal
## record, and a daily routine. Composition root the rest of the game reads
## from — interaction flows (M3+) query identity/routine, LawEngine reads
## criminal_record, and personality is consulted only by systems that decide
## NPC behavior, never shown to the player directly.
##
## Each NPC reacts independently: nothing here is shared state between NPC
## instances, so contacting one NPC never informs another's behavior.
class_name NPC
extends RefCounted

var id: String
var identity: NPCIdentity
var personality: NPCPersonality
var criminal_record: CriminalRecord
var routine: DailyRoutine


func _init(p_id: String, p_identity: NPCIdentity, p_personality: NPCPersonality, p_criminal_record: CriminalRecord, p_routine: DailyRoutine) -> void:
	id = p_id
	identity = p_identity
	personality = p_personality
	criminal_record = p_criminal_record
	routine = p_routine


## Convenience passthrough: this NPC's reaction-category odds given its
## personality and everything in its criminal record so far.
func get_reaction_weights() -> Dictionary:
	return personality.get_reaction_weights(criminal_record)


## Convenience passthrough: what this NPC is doing at the given hour (0-23)
## according to its daily routine.
func get_activity_for_hour(hour: int) -> String:
	return routine.get_state_for_hour(hour)


## Convenience passthrough: the {"priors_by_offense": {...}} shape
## LawEngine expects as an npc_record.
func to_law_npc_record() -> Dictionary:
	return criminal_record.to_npc_record()
