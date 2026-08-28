## Unit tests for src/systems/npc_identity.gd.
extends TestCase


func test_full_name_joins_first_and_last() -> void:
	var identity := NPCIdentity.new()
	identity.first_name = "Jan"
	identity.last_name = "Novák"
	assert_eq(identity.full_name(), "Jan Novák")


func test_age_in_years() -> void:
	var identity := NPCIdentity.new()
	identity.birth_year = 1990
	assert_eq(identity.age_in_years(2026), 36)


func test_age_in_years_never_negative() -> void:
	var identity := NPCIdentity.new()
	identity.birth_year = 2030
	assert_eq(identity.age_in_years(2026), 0)


func test_birth_date_iso_format() -> void:
	var identity := NPCIdentity.new()
	identity.birth_year = 1995
	identity.birth_month = 3
	identity.birth_day = 7
	assert_eq(identity.birth_date_iso(), "1995-03-07")


func test_generate_birth_number_male_shape() -> void:
	var rc := NPCIdentity.generate_birth_number(1990, 5, 20, false, 123)
	assert_eq(rc, "900520/1238")


func test_generate_birth_number_female_month_offset() -> void:
	var rc := NPCIdentity.generate_birth_number(1990, 5, 20, true, 123)
	# yy=90, month encoded as month + 50 -> 55, dd=20 -> "905520/...".
	assert_true(rc.begins_with("905520/"), "expected female month offset, got %s" % rc)


func test_generate_birth_number_round_trips_through_validate() -> void:
	for seq in [0, 1, 42, 500, 999]:
		var rc := NPCIdentity.generate_birth_number(1980, 11, 15, false, seq)
		assert_true(NPCIdentity.validate_birth_number(rc), "expected %s to validate (seq=%d)" % [rc, seq])


func test_generate_birth_number_female_round_trips_through_validate() -> void:
	var rc := NPCIdentity.generate_birth_number(2000, 8, 1, true, 77)
	assert_true(NPCIdentity.validate_birth_number(rc))


func test_validate_birth_number_rejects_bad_check_digit() -> void:
	var rc := NPCIdentity.generate_birth_number(1990, 5, 20, false, 123)
	var parts := rc.split("/")
	var tampered: String = "%s/%s%d" % [parts[0], parts[1].substr(0, 3), (int(parts[1].substr(3, 1)) + 1) % 10]
	assert_false(NPCIdentity.validate_birth_number(tampered))


func test_validate_birth_number_rejects_malformed_input() -> void:
	assert_false(NPCIdentity.validate_birth_number("not-a-number"))
	assert_false(NPCIdentity.validate_birth_number("123456789"))
	assert_false(NPCIdentity.validate_birth_number("12345/6789"))
