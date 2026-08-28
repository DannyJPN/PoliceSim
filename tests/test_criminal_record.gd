## Unit tests for src/systems/criminal_record.gd.
extends TestCase


func test_empty_record_has_no_priors() -> void:
	var record := CriminalRecord.new()
	assert_eq(record.get_total_priors(), 0)
	assert_eq(record.get_prior_count("speeding_minor"), 0)
	assert_false(record.has_been_imprisoned())


func test_add_entry_increments_totals() -> void:
	var record := CriminalRecord.new()
	record.add_entry("speeding_minor", "§125c odst. 1 písm. f) bod 4", "road", 1, "traffic")
	record.add_entry("speeding_minor", "§125c odst. 1 písm. f) bod 4", "road", 3, "traffic")
	record.add_entry("petty_theft", "§205 odst. 1 tr. zákoníku", "city_center", 5, "property")

	assert_eq(record.get_total_priors(), 3)
	assert_eq(record.get_prior_count("speeding_minor"), 2)
	assert_eq(record.get_prior_count("petty_theft"), 1)
	assert_eq(record.get_prior_count("assault"), 0)


func test_prior_count_by_type() -> void:
	var record := CriminalRecord.new()
	record.add_entry("speeding_minor", "code-a", "road", 1, "traffic")
	record.add_entry("speeding_major", "code-b", "road", 2, "traffic")
	record.add_entry("petty_theft", "code-c", "city_center", 3, "property")

	assert_eq(record.get_prior_count_by_type("traffic"), 2)
	assert_eq(record.get_prior_count_by_type("property"), 1)
	assert_eq(record.get_prior_count_by_type("violent"), 0)


func test_imprisonment_tracking() -> void:
	var record := CriminalRecord.new()
	record.add_entry("burglary", "code-a", "residential", 1, "property", 0)
	assert_false(record.has_been_imprisoned())

	record.add_entry("burglary", "code-b", "residential", 10, "property", 90)
	assert_true(record.has_been_imprisoned())
	assert_eq(record.get_imprisonment_count(), 1)


func test_to_npc_record_matches_law_engine_expected_shape() -> void:
	var record := CriminalRecord.new()
	record.add_entry("speeding_minor", "code-a", "road", 1)
	record.add_entry("speeding_minor", "code-a", "road", 2)
	record.add_entry("assault", "code-b", "city_center", 3)

	var npc_record := record.to_npc_record()
	assert_true(npc_record.has("priors_by_offense"))
	assert_eq(npc_record["priors_by_offense"]["speeding_minor"], 2)
	assert_eq(npc_record["priors_by_offense"]["assault"], 1)


func test_to_npc_record_feeds_law_engine_directly() -> void:
	var engine := LawEngine.new()
	engine.load_country("CZ")

	var record := CriminalRecord.new()
	record.add_entry("speeding_major", "§125c odst. 1 písm. a)", "road", 1)

	var npc_record := record.to_npc_record()
	var prior_count := engine.get_prior_count(npc_record, "speeding_major")
	assert_eq(prior_count, 1)

	var sanctions := engine.get_sanctions_for_offense("speeding_major", prior_count)
	assert_true(sanctions[1]["eligible"], "recidivist tier should be unlocked after the recorded prior")


func test_get_entries_returns_a_copy() -> void:
	var record := CriminalRecord.new()
	record.add_entry("speeding_minor", "code-a", "road", 1)
	var entries := record.get_entries()
	entries.clear()
	assert_eq(record.get_total_priors(), 1, "mutating the returned array must not affect the record")
