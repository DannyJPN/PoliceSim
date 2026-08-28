## Unit tests for src/systems/npc_personality.gd.
extends TestCase


func _sum_weights(weights: Dictionary) -> float:
	var total: float = 0.0
	for value: float in weights.values():
		total += value
	return total


func test_default_construction() -> void:
	var personality := NPCPersonality.new()
	assert_eq(personality.offense_tendency, "none")
	assert_eq(personality.base_reaction_category, "cooperative")


func test_reaction_weights_match_base_when_no_record() -> void:
	var personality := NPCPersonality.new("none", "traffic", "submissive")
	var weights := personality.get_reaction_weights(null)
	assert_almost_eq(weights["submissive"], 0.60, 0.001)
	assert_almost_eq(_sum_weights(weights), 1.0, 0.001)


func test_reaction_weights_match_base_with_clean_record() -> void:
	var personality := NPCPersonality.new("none", "traffic", "cooperative")
	var record := CriminalRecord.new()
	var weights := personality.get_reaction_weights(record)
	assert_almost_eq(weights["cooperative"], NPCPersonality.BASE_WEIGHTS["cooperative"]["cooperative"], 0.001)


func test_priors_shift_weight_toward_resistance() -> void:
	var personality := NPCPersonality.new("chronic", "property", "cooperative")
	var clean_record := CriminalRecord.new()
	var dirty_record := CriminalRecord.new()
	for i in range(3):
		dirty_record.add_entry("petty_theft", "code", "city_center", i)

	var clean_weights := personality.get_reaction_weights(clean_record)
	var dirty_weights := personality.get_reaction_weights(dirty_record)

	assert_gt(dirty_weights["aggressive"], clean_weights["aggressive"])
	assert_gt(dirty_weights["fleeing"], clean_weights["fleeing"])
	assert_almost_eq(_sum_weights(dirty_weights), 1.0, 0.001)


func test_prior_imprisonment_escalates_further_than_priors_alone() -> void:
	var personality := NPCPersonality.new("chronic", "violent", "nervous")

	var record_no_prison := CriminalRecord.new()
	record_no_prison.add_entry("assault", "code", "city_center", 1, "violent", 0)

	var record_with_prison := CriminalRecord.new()
	record_with_prison.add_entry("assault", "code", "city_center", 1, "violent", 180)

	var weights_no_prison := personality.get_reaction_weights(record_no_prison)
	var weights_with_prison := personality.get_reaction_weights(record_with_prison)

	assert_gt(weights_with_prison["fleeing"] + weights_with_prison["aggressive"],
		weights_no_prison["fleeing"] + weights_no_prison["aggressive"])


func test_escalation_never_exceeds_the_compliant_pool() -> void:
	var personality := NPCPersonality.new("chronic", "violent", "submissive")
	var record := CriminalRecord.new()
	for i in range(50):
		record.add_entry("assault", "code", "city_center", i, "violent", 90)

	var weights := personality.get_reaction_weights(record)
	assert_almost_eq(_sum_weights(weights), 1.0, 0.001)
	for key: String in weights.keys():
		assert_true(weights[key] >= -0.0001, "weight for %s went negative: %s" % [key, weights[key]])


func test_get_escalation_zero_for_clean_record() -> void:
	var personality := NPCPersonality.new()
	assert_eq(personality.get_escalation(CriminalRecord.new()), 0.0)


func test_get_escalation_caps_at_prior_cap() -> void:
	var personality := NPCPersonality.new()
	var record_at_cap := CriminalRecord.new()
	for i in range(NPCPersonality.PRIOR_CAP):
		record_at_cap.add_entry("speeding_minor", "code", "road", i)

	var record_beyond_cap := CriminalRecord.new()
	for i in range(NPCPersonality.PRIOR_CAP + 10):
		record_beyond_cap.add_entry("speeding_minor", "code", "road", i)

	assert_eq(personality.get_escalation(record_at_cap), personality.get_escalation(record_beyond_cap))
