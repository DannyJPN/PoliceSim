## NPC identity — the part of an NPC that is always visible/known to the
## player once documents are checked: name, birth date, national ID number,
## driver's license status, current outfit, and the seeds used by later
## systems (M6+) to render a persistent procedural face and pick a voice.
##
## Identity never varies between game sessions for a given NPC — it is the
## "paper trail" a player can look up on the tablet, as opposed to
## NPCPersonality, which is hidden and drives behavior.
class_name NPCIdentity
extends RefCounted

enum Gender { MALE, FEMALE }

var first_name: String = ""
var last_name: String = ""
var gender: Gender = Gender.MALE
var birth_year: int = 2000
var birth_month: int = 1
var birth_day: int = 1
var birth_number: String = ""
var has_drivers_license: bool = false
var outfit: String = "casual"
var face_seed: int = 0
var voice_id: String = "voice_01"


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


func age_in_years(current_year: int) -> int:
	return max(0, current_year - birth_year)


## Formats the birth date as ISO-8601 (YYYY-MM-DD).
func birth_date_iso() -> String:
	return "%04d-%02d-%02d" % [birth_year, birth_month, birth_day]


## Generates a Czech-style "rodné číslo" (birth number) for the given birth
## date and gender: 6-digit date (YYMMDD, month +50 for women) followed by a
## slash and a 4-digit suffix, where the whole 9-digit number (date +
## 3-digit sequence) is divisible by 11 once the resulting check digit is
## appended. `sequence` (000-999) disambiguates NPCs sharing a birth date
## and gender — the caller is responsible for not reusing one.
##
## This mirrors the real algorithm closely enough for gameplay purposes but
## skips the historical 1954-and-earlier and 20th/21st-century-overflow
## edge cases, which are not relevant to any in-game NPC.
static func generate_birth_number(year: int, month: int, day: int, is_female: bool, sequence: int) -> String:
	var yy: int = year % 100
	var mm: int = month + 50 if is_female else month
	var seq: int = clampi(sequence, 0, 999)

	var base9 := "%02d%02d%02d%03d" % [yy, mm, day, seq]
	var value9 := base9.to_int()
	var remainder := value9 % 11
	var check_digit: int = 0 if remainder == 10 else remainder

	return "%s/%s%d" % [base9.substr(0, 6), base9.substr(6, 3), check_digit]


## Validates the check digit (and basic shape) of a birth number produced by
## generate_birth_number(). Returns false for malformed input.
static func validate_birth_number(rodne_cislo: String) -> bool:
	var parts := rodne_cislo.split("/")
	if parts.size() != 2:
		return false
	if parts[0].length() != 6 or parts[1].length() != 4:
		return false
	if not (parts[0].is_valid_int() and parts[1].is_valid_int()):
		return false

	var base9 := parts[0] + parts[1].substr(0, 3)
	var check_digit := int(parts[1].substr(3, 1))
	var value9 := base9.to_int()
	var remainder := value9 % 11
	var expected_check: int = 0 if remainder == 10 else remainder

	return check_digit == expected_check
