## Unit tests for src/systems/law_engine.gd.
extends TestCase


func _make_engine() -> LawEngine:
	var engine := LawEngine.new()
	engine.load_country("CZ")
	return engine


func test_schema_loads() -> void:
	var engine := LawEngine.new()
	assert_false(engine.schema.is_empty(), "schema.json should load in _init")


func test_load_known_country_succeeds() -> void:
	var engine := LawEngine.new()
	var ok := engine.load_country("CZ")
	assert_true(ok, "loading CZ should succeed")
	assert_true(engine.is_loaded())
	assert_eq(engine.last_errors.size(), 0)
	assert_eq(engine.country_code, "CZ")


func test_load_unknown_country_fails() -> void:
	var engine := LawEngine.new()
	var ok := engine.load_country("ZZ")
	assert_false(ok, "loading a nonexistent country file should fail")
	assert_false(engine.is_loaded())
	assert_gt(engine.last_errors.size(), 0, "last_errors should explain the failure")


func test_validate_rejects_missing_required_field() -> void:
	var engine := LawEngine.new()
	var bad_data := {
		"country": "CZ",
		"currency": "CZK",
		"offenses": []
	}
	var errors := engine.validate(bad_data)
	assert_gt(errors.size(), 0, "missing country_name should produce a validation error")


func test_validate_rejects_bad_enum_value() -> void:
	var engine := LawEngine.new()
	var bad_data := {
		"country": "CZ",
		"country_name": {"cs": "Česko", "en": "Czechia"},
		"currency": "CZK",
		"offenses": [
			{
				"id": "bad_offense",
				"type": "not_a_real_type",
				"name": {"cs": "Test", "en": "Test"},
				"zones": ["road"],
				"time_of_day": ["any"],
				"sanctions": [
					{
						"code": "§1",
						"name": {"cs": "Test", "en": "Test"},
						"fine_min": 0,
						"fine_max": 0,
						"warning_allowed": true,
						"imprisonment_possible": false,
						"recidivism_multiplier": 1.0,
						"min_priors": 0
					}
				]
			}
		]
	}
	var errors := engine.validate(bad_data)
	assert_gt(errors.size(), 0, "invalid offense type should fail enum validation")


func test_validate_accepts_loaded_cz_data() -> void:
	var engine := LawEngine.new()
	# The file only counts as valid if load_country's own validate() pass
	# succeeded, so this mostly re-confirms load_country's contract.
	var ok := engine.load_country("CZ")
	assert_true(ok)
	var errors := engine.validate(engine.country_data)
	assert_eq(errors.size(), 0, "loaded CZ data should validate cleanly against its own schema")


func test_get_offense_returns_expected_offense() -> void:
	var engine := _make_engine()
	var offense := engine.get_offense("speeding_minor")
	assert_false(offense.is_empty())
	assert_eq(offense.get("type"), "traffic")
	assert_eq(offense.get("id"), "speeding_minor")


func test_get_offense_unknown_id_returns_empty() -> void:
	var engine := _make_engine()
	var offense := engine.get_offense("does_not_exist")
	assert_true(offense.is_empty())


func test_offenses_filtered_by_zone_and_time() -> void:
	var engine := _make_engine()

	# disturbing_night_peace only applies at night, in residential/city_center.
	var night_offenses := engine.get_offenses_for_context("residential", "night")
	var found_night := false
	for offense: Dictionary in night_offenses:
		if offense.get("id") == "disturbing_night_peace":
			found_night = true
	assert_true(found_night, "disturbing_night_peace should be offered in residential zone at night")

	var day_offenses := engine.get_offenses_for_context("residential", "day")
	var found_day := false
	for offense: Dictionary in day_offenses:
		if offense.get("id") == "disturbing_night_peace":
			found_day = true
	assert_false(found_day, "disturbing_night_peace should not be offered during the day")


func test_offenses_filtered_by_zone_excludes_wrong_zone() -> void:
	var engine := _make_engine()
	var rural_offenses := engine.get_offenses_for_context("rural", "day")
	var ids: Array = []
	for offense: Dictionary in rural_offenses:
		ids.append(offense.get("id"))
	assert_has(ids, "poaching")
	assert_false(ids.has("speeding_minor"), "road-only offense should not appear in rural zone")


func test_any_time_offense_matches_day_and_night() -> void:
	var engine := _make_engine()
	var day_offenses := engine.get_offenses_for_context("road", "day")
	var night_offenses := engine.get_offenses_for_context("road", "night")
	var day_ids: Array = day_offenses.map(func(o: Dictionary) -> String: return o.get("id"))
	var night_ids: Array = night_offenses.map(func(o: Dictionary) -> String: return o.get("id"))
	assert_has(day_ids, "speeding_minor")
	assert_has(night_ids, "speeding_minor")


func test_fine_range_without_recidivism() -> void:
	var engine := _make_engine()
	var fine_range := engine.calculate_fine_range("speeding_minor", "§125c odst. 1 písm. f) bod 4", 0)
	assert_eq(fine_range["min"], 1000)
	assert_eq(fine_range["max"], 2500)


func test_fine_range_scales_with_recidivism_multiplier() -> void:
	var engine := _make_engine()
	# speeding_minor has recidivism_multiplier 1.3; one prior offense -> *1.3
	var fine_range := engine.calculate_fine_range("speeding_minor", "§125c odst. 1 písm. f) bod 4", 1)
	assert_eq(fine_range["min"], int(round(1000.0 * 1.3)))
	assert_eq(fine_range["max"], int(round(2500.0 * 1.3)))


func test_fine_range_caps_recidivism_steps() -> void:
	var engine := _make_engine()
	var at_cap := engine.calculate_fine_range("speeding_minor", "§125c odst. 1 písm. f) bod 4", LawEngine.MAX_RECIDIVISM_STEPS)
	var beyond_cap := engine.calculate_fine_range("speeding_minor", "§125c odst. 1 písm. f) bod 4", LawEngine.MAX_RECIDIVISM_STEPS + 10)
	assert_eq(at_cap["min"], beyond_cap["min"], "fine should stop growing past MAX_RECIDIVISM_STEPS priors")
	assert_eq(at_cap["max"], beyond_cap["max"])


func test_fine_range_unknown_sanction_returns_zero() -> void:
	var engine := _make_engine()
	var fine_range := engine.calculate_fine_range("speeding_minor", "not-a-real-code", 0)
	assert_eq(fine_range["min"], 0)
	assert_eq(fine_range["max"], 0)


func test_get_prior_count_reads_npc_record() -> void:
	var engine := _make_engine()
	var npc_record := {"priors_by_offense": {"petty_theft": 3}}
	assert_eq(engine.get_prior_count(npc_record, "petty_theft"), 3)
	assert_eq(engine.get_prior_count(npc_record, "assault"), 0)


func test_sanctions_for_offense_marks_recidivist_tier_ineligible_for_first_timer() -> void:
	var engine := _make_engine()
	var sanctions := engine.get_sanctions_for_offense("speeding_major", 0)
	assert_eq(sanctions.size(), 2)

	var first_tier: Dictionary = sanctions[0]
	var recidivist_tier: Dictionary = sanctions[1]
	assert_true(first_tier["eligible"], "base speeding_major sanction should be available to a first-time offender")
	assert_false(recidivist_tier["eligible"], "recidivist tier requires min_priors 1")
	assert_true(recidivist_tier.has("ineligible_reason"))


func test_sanctions_for_offense_unlocks_recidivist_tier_after_prior() -> void:
	var engine := _make_engine()
	var sanctions := engine.get_sanctions_for_offense("speeding_major", 1)
	var recidivist_tier: Dictionary = sanctions[1]
	assert_true(recidivist_tier["eligible"], "recidivist tier should unlock once the NPC has 1+ prior")
	assert_false(recidivist_tier.has("ineligible_reason"))


func test_sanctions_for_offense_includes_computed_fine_range() -> void:
	var engine := _make_engine()
	var sanctions := engine.get_sanctions_for_offense("speeding_minor", 2)
	var sanction: Dictionary = sanctions[0]
	assert_eq(sanction["base_fine_min"], 1000)
	assert_eq(sanction["fine_min"], int(round(1000.0 * pow(1.3, 2))))


func test_warning_allowed_true_for_minor_offense() -> void:
	var engine := _make_engine()
	assert_true(engine.is_warning_allowed("speeding_minor", "§125c odst. 1 písm. f) bod 4"))


func test_warning_allowed_false_for_severe_offense() -> void:
	var engine := _make_engine()
	assert_false(engine.is_warning_allowed("drunk_driving", "§274 odst. 1 tr. zákoníku"))


func test_imprisonment_possible_true_for_burglary() -> void:
	var engine := _make_engine()
	assert_true(engine.is_imprisonment_possible("burglary", "§205 odst. 2 tr. zákoníku"))


func test_imprisonment_possible_false_for_parking() -> void:
	var engine := _make_engine()
	assert_false(engine.is_imprisonment_possible("illegal_parking", "§125c odst. 1 písm. k)"))


func test_warning_and_imprisonment_false_for_unknown_sanction() -> void:
	var engine := _make_engine()
	assert_false(engine.is_warning_allowed("speeding_minor", "no-such-code"))
	assert_false(engine.is_imprisonment_possible("speeding_minor", "no-such-code"))


func test_all_cz_offenses_cover_every_zone() -> void:
	var engine := _make_engine()
	var zones := ["city_center", "residential", "industrial", "road", "rural"]
	for zone in zones:
		var offenses := engine.get_offenses_for_context(zone, "day")
		assert_gt(offenses.size(), 0, "zone '%s' should have at least one offense defined" % zone)
