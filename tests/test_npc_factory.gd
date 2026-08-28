## Unit tests for src/systems/npc_factory.gd.
extends TestCase


func test_generate_is_deterministic_for_a_given_seed() -> void:
	var npc_a := NPCFactory.generate(12345)
	var npc_b := NPCFactory.generate(12345)

	assert_eq(npc_a.identity.full_name(), npc_b.identity.full_name())
	assert_eq(npc_a.identity.birth_number, npc_b.identity.birth_number)
	assert_eq(npc_a.identity.has_drivers_license, npc_b.identity.has_drivers_license)
	assert_eq(npc_a.personality.offense_tendency, npc_b.personality.offense_tendency)
	assert_eq(npc_a.personality.base_reaction_category, npc_b.personality.base_reaction_category)


func test_different_seeds_usually_produce_different_npcs() -> void:
	var npc_a := NPCFactory.generate(1)
	var npc_b := NPCFactory.generate(2)
	assert_ne(npc_a.identity.birth_number, npc_b.identity.birth_number)


func test_default_id_derived_from_seed() -> void:
	var npc := NPCFactory.generate(777)
	assert_eq(npc.id, "npc_777")


func test_custom_id_is_used_when_provided() -> void:
	var npc := NPCFactory.generate(777, "npc_officer_test")
	assert_eq(npc.id, "npc_officer_test")


func test_generated_birth_number_is_valid() -> void:
	for seed in [1, 2, 3, 100, 4242]:
		var npc := NPCFactory.generate(seed)
		assert_true(NPCIdentity.validate_birth_number(npc.identity.birth_number),
			"seed %d produced an invalid birth number: %s" % [seed, npc.identity.birth_number])


func test_generated_age_within_configured_bounds() -> void:
	for seed in range(20):
		var npc := NPCFactory.generate(seed, "", 2026)
		var age := npc.identity.age_in_years(2026)
		assert_true(age >= NPCFactory.MIN_AGE and age <= NPCFactory.MAX_AGE,
			"seed %d produced out-of-range age %d" % [seed, age])


func test_generated_personality_fields_are_valid() -> void:
	for seed in range(20):
		var npc := NPCFactory.generate(seed)
		assert_has(NPCPersonality.TENDENCIES, npc.personality.offense_tendency)
		assert_has(NPCPersonality.OFFENSE_TYPES, npc.personality.offense_type)
		assert_has(NPCPersonality.REACTIONS, npc.personality.base_reaction_category)


func test_generated_routine_covers_full_day() -> void:
	for seed in range(20):
		var npc := NPCFactory.generate(seed)
		assert_true(npc.routine.covers_full_day(), "seed %d produced a routine with gaps" % seed)


func test_fresh_npc_has_empty_criminal_record() -> void:
	var npc := NPCFactory.generate(999)
	assert_eq(npc.criminal_record.get_total_priors(), 0)


func test_current_year_shifts_birth_year_but_not_identity_otherwise() -> void:
	var npc_2026 := NPCFactory.generate(55, "", 2026)
	var npc_2030 := NPCFactory.generate(55, "", 2030)
	assert_eq(npc_2026.identity.first_name, npc_2030.identity.first_name)
	assert_eq(npc_2026.identity.last_name, npc_2030.identity.last_name)
