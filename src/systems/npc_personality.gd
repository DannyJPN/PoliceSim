## An NPC's hidden personality profile. Never shown to the player directly —
## only inferred through behavior. Holds the NPC's propensity to offend and
## its fixed base reaction category, plus the logic that turns a criminal
## record into reaction *probabilities* for whichever system (dialog/AI,
## M7) ends up rolling the dice during an actual stop.
##
## The base reaction category itself does not drift on its own; only a
## growing criminal record (more priors, a past imprisonment) shifts the
## odds computed by get_reaction_weights() toward resisting arrest.
class_name NPCPersonality
extends RefCounted

const TENDENCIES: Array[String] = ["none", "occasional", "chronic"]
const OFFENSE_TYPES: Array[String] = ["traffic", "violent", "property", "public_order"]
const REACTIONS: Array[String] = ["submissive", "cooperative", "nervous", "aggressive", "fleeing"]

## Base probability distribution over reaction categories, keyed by the
## NPC's fixed base_reaction_category. Each row sums to 1.0.
const BASE_WEIGHTS: Dictionary = {
	"submissive": {"submissive": 0.60, "cooperative": 0.25, "nervous": 0.10, "aggressive": 0.03, "fleeing": 0.02},
	"cooperative": {"submissive": 0.15, "cooperative": 0.55, "nervous": 0.20, "aggressive": 0.06, "fleeing": 0.04},
	"nervous": {"submissive": 0.10, "cooperative": 0.20, "nervous": 0.50, "aggressive": 0.12, "fleeing": 0.08},
	"aggressive": {"submissive": 0.05, "cooperative": 0.10, "nervous": 0.15, "aggressive": 0.55, "fleeing": 0.15},
	"fleeing": {"submissive": 0.05, "cooperative": 0.10, "nervous": 0.10, "aggressive": 0.15, "fleeing": 0.60},
}

## How much escalation each prior offense adds, capped at PRIOR_CAP priors.
const ESCALATION_PER_PRIOR: float = 0.03
const PRIOR_CAP: int = 5
## Extra escalation applied once the NPC has ever been imprisoned.
const IMPRISONMENT_ESCALATION: float = 0.25

var offense_tendency: String = "none"
var offense_type: String = "property"
var base_reaction_category: String = "cooperative"


func _init(p_offense_tendency: String = "none", p_offense_type: String = "property", p_base_reaction_category: String = "cooperative") -> void:
	offense_tendency = p_offense_tendency
	offense_type = p_offense_type
	base_reaction_category = p_base_reaction_category


## Computes how much the NPC's total priors + any past imprisonment push
## the odds toward resisting arrest (0.0 = no push).
func get_escalation(criminal_record: CriminalRecord) -> float:
	if criminal_record == null:
		return 0.0
	var priors: int = criminal_record.get_total_priors()
	var escalation: float = min(priors, PRIOR_CAP) * ESCALATION_PER_PRIOR
	if criminal_record.has_been_imprisoned():
		escalation += IMPRISONMENT_ESCALATION
	return escalation


## Returns a probability distribution over REACTIONS reflecting this NPC's
## base category, pulled toward "aggressive"/"fleeing" by recidivism and
## prior imprisonment. Weights always sum to (approximately) 1.0.
func get_reaction_weights(criminal_record: CriminalRecord) -> Dictionary:
	var base: Dictionary = BASE_WEIGHTS.get(base_reaction_category, BASE_WEIGHTS["cooperative"])
	var weights: Dictionary = base.duplicate()

	var escalation: float = get_escalation(criminal_record)
	if escalation <= 0.0:
		return weights

	var compliant_pool: float = weights["submissive"] + weights["cooperative"] + weights["nervous"]
	var clamped_escalation: float = min(escalation, compliant_pool)
	var scale: float = (compliant_pool - clamped_escalation) / compliant_pool if compliant_pool > 0.0 else 0.0

	weights["submissive"] *= scale
	weights["cooperative"] *= scale
	weights["nervous"] *= scale
	weights["aggressive"] += clamped_escalation / 2.0
	weights["fleeing"] += clamped_escalation / 2.0

	return _normalize(weights)


func _normalize(weights: Dictionary) -> Dictionary:
	var total: float = 0.0
	for key: String in weights.keys():
		total += float(weights[key])
	if total <= 0.0:
		return weights
	var normalized: Dictionary = {}
	for key: String in weights.keys():
		normalized[key] = float(weights[key]) / total
	return normalized
