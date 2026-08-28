## Law Engine
##
## Loads a country's law definitions from data/laws/{COUNTRY}.json (validated
## against data/laws/schema.json), and answers questions the interaction
## flow needs: which offenses apply in a given zone/time, which sanctions are
## on offer for an offense given an NPC's criminal record, what fine range
## applies once recidivism is factored in, and whether a warning or
## imprisonment is legally possible for a given sanction.
class_name LawEngine
extends RefCounted

const LAWS_DIR := "res://data/laws"
const SCHEMA_PATH := "res://data/laws/schema.json"

## How many prior offenses feed into the recidivism multiplier before it
## stops compounding further, to keep fines from growing unbounded.
const MAX_RECIDIVISM_STEPS := 3

var schema: Dictionary = {}
var country_code: String = ""
var country_data: Dictionary = {}
var last_errors: Array[String] = []

var _offense_index: Dictionary = {}


func _init() -> void:
	_load_schema()


func _load_schema() -> void:
	var data: Variant = _read_json_file(SCHEMA_PATH)
	if data is Dictionary:
		schema = data
	else:
		schema = {}


## Loads and validates data/laws/{code}.json, e.g. load_country("CZ").
## Returns true on success; on failure, country_data is left unchanged and
## last_errors explains why.
func load_country(code: String) -> bool:
	last_errors = []

	if schema.is_empty():
		last_errors.append("Law schema (%s) could not be loaded." % SCHEMA_PATH)
		return false

	var path := "%s/%s.json" % [LAWS_DIR, code]
	var data: Variant = _read_json_file(path)
	if not (data is Dictionary):
		last_errors.append("Could not read or parse law file: %s" % path)
		return false

	var errors := validate(data)
	if not errors.is_empty():
		last_errors = errors
		return false

	country_code = code
	country_data = data
	_build_offense_index()
	return true


func is_loaded() -> bool:
	return not country_data.is_empty()


## Validates arbitrary law data against the loaded schema. Returns an empty
## array when valid, otherwise a list of human-readable error messages.
func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if schema.is_empty():
		errors.append("Schema not loaded.")
		return errors
	_validate_node(data, schema, "$", schema, errors)
	return errors


func get_offense(offense_id: String) -> Dictionary:
	return _offense_index.get(offense_id, {})


## Returns all offenses that can occur in the given zone at the given time
## of day ("day" or "night"). An offense whose time_of_day includes "any"
## matches both.
func get_offenses_for_context(zone: String, time_of_day: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offense: Dictionary in country_data.get("offenses", []):
		var zones: Array = offense.get("zones", [])
		var times: Array = offense.get("time_of_day", [])
		if zones.has(zone) and (times.has(time_of_day) or times.has("any")):
			result.append(offense)
	return result


func get_sanction(offense_id: String, sanction_code: String) -> Dictionary:
	var offense := get_offense(offense_id)
	for sanction: Dictionary in offense.get("sanctions", []):
		if sanction.get("code", "") == sanction_code:
			return sanction
	return {}


## Reads how many prior offenses of offense_id an NPC's criminal record
## contains. npc_record is expected to carry a "priors_by_offense"
## dictionary keyed by offense id, e.g. {"priors_by_offense": {"petty_theft": 2}}.
func get_prior_count(npc_record: Dictionary, offense_id: String) -> int:
	var by_offense: Dictionary = npc_record.get("priors_by_offense", {})
	return int(by_offense.get(offense_id, 0))


## Computes the legal fine range for a sanction, scaled by its recidivism
## multiplier raised to the (capped) number of prior offenses. prior_count
## of 0 returns the base range unchanged.
func calculate_fine_range(offense_id: String, sanction_code: String, prior_count: int) -> Dictionary:
	var sanction := get_sanction(offense_id, sanction_code)
	if sanction.is_empty():
		return {"min": 0, "max": 0}

	var multiplier: float = float(sanction.get("recidivism_multiplier", 1.0))
	var steps: int = clampi(prior_count, 0, MAX_RECIDIVISM_STEPS)
	var factor: float = pow(multiplier, steps)

	var fine_min: int = int(round(float(sanction.get("fine_min", 0)) * factor))
	var fine_max: int = int(round(float(sanction.get("fine_max", 0)) * factor))
	return {"min": fine_min, "max": fine_max}


## Returns every sanction defined for an offense, each augmented with the
## recidivism-adjusted fine range and an "eligible" flag (false when the
## NPC's prior_count is below the sanction's min_priors requirement, e.g. a
## harsher tier only unlocked after a repeat offense). Ineligible entries
## carry an "ineligible_reason" for the UI to display grayed out.
func get_sanctions_for_offense(offense_id: String, prior_count: int) -> Array[Dictionary]:
	var offense := get_offense(offense_id)
	var result: Array[Dictionary] = []
	for sanction: Dictionary in offense.get("sanctions", []):
		var min_priors: int = int(sanction.get("min_priors", 0))
		var eligible: bool = prior_count >= min_priors
		var fine_range := calculate_fine_range(offense_id, String(sanction.get("code", "")), prior_count)

		var entry := sanction.duplicate(true)
		entry["base_fine_min"] = sanction.get("fine_min", 0)
		entry["base_fine_max"] = sanction.get("fine_max", 0)
		entry["fine_min"] = fine_range["min"]
		entry["fine_max"] = fine_range["max"]
		entry["eligible"] = eligible
		if not eligible:
			entry["ineligible_reason"] = "Vyžaduje minimálně %d předchozích záznamů (NPC má %d)." % [min_priors, prior_count]
		result.append(entry)
	return result


func is_warning_allowed(offense_id: String, sanction_code: String) -> bool:
	return bool(get_sanction(offense_id, sanction_code).get("warning_allowed", false))


func is_imprisonment_possible(offense_id: String, sanction_code: String) -> bool:
	return bool(get_sanction(offense_id, sanction_code).get("imprisonment_possible", false))


func _build_offense_index() -> void:
	_offense_index = {}
	for offense: Dictionary in country_data.get("offenses", []):
		_offense_index[offense.get("id", "")] = offense


func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


# --- Minimal JSON Schema (draft-07 subset) validator ---------------------
# Supports the constructs actually used by data/laws/schema.json: type,
# $ref (local "#/..." only), enum, pattern, minLength, minimum, minItems,
# required, properties, additionalProperties: false, and items.

func _validate_node(data: Variant, node_schema: Dictionary, path: String, root_schema: Dictionary, errors: Array[String]) -> void:
	if node_schema.has("$ref"):
		var resolved := _resolve_ref(String(node_schema["$ref"]), root_schema)
		if resolved.is_empty():
			errors.append("%s: unresolved $ref '%s'" % [path, node_schema["$ref"]])
			return
		_validate_node(data, resolved, path, root_schema, errors)
		return

	if node_schema.has("type") and not _check_type(data, String(node_schema["type"])):
		errors.append("%s: expected type '%s'" % [path, node_schema["type"]])
		return

	if node_schema.has("enum"):
		var allowed: Array = node_schema["enum"]
		if not allowed.has(data):
			errors.append("%s: value '%s' not in allowed set %s" % [path, str(data), str(allowed)])

	if node_schema.has("pattern") and data is String:
		var re := RegEx.new()
		re.compile(String(node_schema["pattern"]))
		if re.search(data) == null:
			errors.append("%s: value '%s' does not match pattern '%s'" % [path, data, node_schema["pattern"]])

	if node_schema.has("minLength") and data is String and data.length() < int(node_schema["minLength"]):
		errors.append("%s: string shorter than minLength %s" % [path, node_schema["minLength"]])

	if node_schema.has("minimum") and (data is int or data is float) and data < float(node_schema["minimum"]):
		errors.append("%s: value %s below minimum %s" % [path, str(data), node_schema["minimum"]])

	if data is Dictionary:
		_validate_object(data, node_schema, path, root_schema, errors)
	elif data is Array:
		_validate_array(data, node_schema, path, root_schema, errors)


func _validate_object(data: Dictionary, node_schema: Dictionary, path: String, root_schema: Dictionary, errors: Array[String]) -> void:
	if node_schema.has("required"):
		for req_key: String in node_schema["required"]:
			if not data.has(req_key):
				errors.append("%s: missing required property '%s'" % [path, req_key])

	if node_schema.get("additionalProperties", true) == false and node_schema.has("properties"):
		var allowed_keys: Array = (node_schema["properties"] as Dictionary).keys()
		for key: String in data.keys():
			if not allowed_keys.has(key):
				errors.append("%s: unexpected property '%s'" % [path, key])

	if node_schema.has("properties"):
		var properties: Dictionary = node_schema["properties"]
		for key: String in properties.keys():
			if data.has(key):
				_validate_node(data[key], properties[key], "%s.%s" % [path, key], root_schema, errors)


func _validate_array(data: Array, node_schema: Dictionary, path: String, root_schema: Dictionary, errors: Array[String]) -> void:
	if node_schema.has("minItems") and data.size() < int(node_schema["minItems"]):
		errors.append("%s: array has %d item(s), expected at least %s" % [path, data.size(), node_schema["minItems"]])

	if node_schema.has("items"):
		for i in range(data.size()):
			_validate_node(data[i], node_schema["items"], "%s[%d]" % [path, i], root_schema, errors)


func _resolve_ref(ref_path: String, root_schema: Dictionary) -> Dictionary:
	if not ref_path.begins_with("#/"):
		return {}
	var node: Variant = root_schema
	for part in ref_path.substr(2).split("/"):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			return {}
	return node if node is Dictionary else {}


func _check_type(data: Variant, type_name: String) -> bool:
	match type_name:
		"object":
			return data is Dictionary
		"array":
			return data is Array
		"string":
			return data is String
		"boolean":
			return data is bool
		"integer":
			return (data is int) or (data is float and is_equal_approx(data, round(data)))
		"number":
			return (data is int) or (data is float)
		_:
			return true
