## Procedurally generates NPCs from a seed, so a given seed always produces
## the exact same NPC (useful for tests, and for regenerating an NPC's
## identity deterministically from a save file without storing every field).
class_name NPCFactory
extends RefCounted

const MALE_FIRST_NAMES: Array[String] = [
	"Jan", "Petr", "Pavel", "Josef", "Jiří", "Tomáš", "Martin", "Miroslav",
	"František", "Zdeněk", "Michal", "Václav", "Karel", "Milan", "Lukáš",
]
const FEMALE_FIRST_NAMES: Array[String] = [
	"Marie", "Jana", "Eva", "Hana", "Anna", "Lenka", "Kateřina", "Petra",
	"Lucie", "Věra", "Alena", "Veronika", "Michaela", "Barbora", "Kristýna",
]

## [masculine_surname, feminine_surname] pairs — kept as an explicit list
## rather than a suffix rule, since Czech surname declension has enough
## exceptions (adjectival vs. substantive surnames) to make a rule unreliable.
const SURNAME_PAIRS: Array = [
	["Novák", "Nováková"], ["Svoboda", "Svobodová"], ["Novotný", "Novotná"],
	["Dvořák", "Dvořáková"], ["Černý", "Černá"], ["Procházka", "Procházková"],
	["Kučera", "Kučerová"], ["Veselý", "Veselá"], ["Horák", "Horáková"],
	["Němec", "Němcová"], ["Marek", "Marková"], ["Pospíšil", "Pospíšilová"],
	["Pokorný", "Pokorná"], ["Hájek", "Hájková"], ["Král", "Králová"],
]

const OUTFITS: Array[String] = ["casual", "work_uniform", "formal", "sportswear"]

const MIN_AGE := 18
const MAX_AGE := 75

const TENDENCY_WEIGHTS: Dictionary = {"none": 0.6, "occasional": 0.3, "chronic": 0.1}

## Reaction-category odds correlated with offense tendency: NPCs with no
## history of offending skew toward compliant base categories, chronic
## offenders skew toward aggressive/fleeing.
const REACTION_WEIGHTS_BY_TENDENCY: Dictionary = {
	"none": {"submissive": 0.35, "cooperative": 0.40, "nervous": 0.15, "aggressive": 0.07, "fleeing": 0.03},
	"occasional": {"submissive": 0.15, "cooperative": 0.30, "nervous": 0.30, "aggressive": 0.15, "fleeing": 0.10},
	"chronic": {"submissive": 0.05, "cooperative": 0.15, "nervous": 0.20, "aggressive": 0.35, "fleeing": 0.25},
}


## Generates one NPC. Passing the same seed always yields an identical NPC
## (name, birth data, personality, routine). `npc_id` defaults to
## "npc_<seed>" when left empty. `current_year` anchors age -> birth year.
static func generate(seed: int, npc_id: String = "", current_year: int = 2026) -> NPC:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var is_female: bool = rng.randf() < 0.5
	var gender: NPCIdentity.Gender = NPCIdentity.Gender.FEMALE if is_female else NPCIdentity.Gender.MALE

	var surname_pair: Array = SURNAME_PAIRS[rng.randi_range(0, SURNAME_PAIRS.size() - 1)]
	var last_name: String = surname_pair[1] if is_female else surname_pair[0]
	var first_names: Array[String] = FEMALE_FIRST_NAMES if is_female else MALE_FIRST_NAMES
	var first_name: String = first_names[rng.randi_range(0, first_names.size() - 1)]

	var age: int = rng.randi_range(MIN_AGE, MAX_AGE)
	var birth_year: int = current_year - age
	var birth_month: int = rng.randi_range(1, 12)
	var birth_day: int = rng.randi_range(1, 28)
	var sequence: int = rng.randi_range(0, 999)

	var identity := NPCIdentity.new()
	identity.first_name = first_name
	identity.last_name = last_name
	identity.gender = gender
	identity.birth_year = birth_year
	identity.birth_month = birth_month
	identity.birth_day = birth_day
	identity.birth_number = NPCIdentity.generate_birth_number(birth_year, birth_month, birth_day, is_female, sequence)
	identity.has_drivers_license = rng.randf() < 0.8
	identity.outfit = OUTFITS[rng.randi_range(0, OUTFITS.size() - 1)]
	identity.face_seed = rng.randi()
	identity.voice_id = "voice_%02d" % rng.randi_range(1, 8)

	var tendency: String = _weighted_pick(rng, TENDENCY_WEIGHTS)
	var offense_type: String = NPCPersonality.OFFENSE_TYPES[rng.randi_range(0, NPCPersonality.OFFENSE_TYPES.size() - 1)]
	var reaction_category: String = _weighted_pick(rng, REACTION_WEIGHTS_BY_TENDENCY[tendency])
	var personality := NPCPersonality.new(tendency, offense_type, reaction_category)

	var routine: DailyRoutine
	match rng.randi_range(0, 2):
		0:
			routine = DailyRoutine.worker_routine()
		1:
			routine = DailyRoutine.idle_routine()
		_:
			routine = DailyRoutine.night_shift_routine()

	var resolved_id: String = npc_id if npc_id != "" else "npc_%d" % seed
	return NPC.new(resolved_id, identity, personality, CriminalRecord.new(), routine)


## Picks a key from `weights` (values need not sum to 1.0) using `rng`.
static func _weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total: float = 0.0
	for value: float in weights.values():
		total += value

	var roll: float = rng.randf() * total
	var cumulative: float = 0.0
	var keys: Array = weights.keys()
	for key: String in keys:
		cumulative += float(weights[key])
		if roll <= cumulative:
			return key
	return keys[-1]
