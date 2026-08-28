## Minimal base class for GDScript unit tests, executed headlessly by
## tests/test_runner.gd (godot --headless --script res://tests/test_runner.gd).
## Test files extend this class and define methods named test_*; each such
## method is called automatically and its assert_* results are aggregated.
class_name TestCase
extends RefCounted

var _passed := 0
var _failed := 0
var _failures: Array[String] = []


func assert_true(condition: bool, message: String = "") -> void:
	_record(condition, message if message != "" else "assert_true", "expected true, got false")


func assert_false(condition: bool, message: String = "") -> void:
	_record(not condition, message if message != "" else "assert_false", "expected false, got true")


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	var ok: bool = actual == expected
	_record(ok, message if message != "" else "assert_eq", "expected %s, got %s" % [str(expected), str(actual)])


func assert_ne(actual: Variant, expected: Variant, message: String = "") -> void:
	var ok: bool = actual != expected
	_record(ok, message if message != "" else "assert_ne", "expected value different from %s" % str(expected))


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	var ok: bool = abs(actual - expected) <= tolerance
	_record(ok, message if message != "" else "assert_almost_eq", "expected ~%s (±%s), got %s" % [expected, tolerance, actual])


func assert_gt(actual: float, expected: float, message: String = "") -> void:
	_record(actual > expected, message if message != "" else "assert_gt", "expected %s > %s" % [actual, expected])


func assert_has(container: Variant, value: Variant, message: String = "") -> void:
	var ok: bool = false
	if container is Array:
		ok = (container as Array).has(value)
	elif container is Dictionary:
		ok = (container as Dictionary).has(value)
	_record(ok, message if message != "" else "assert_has", "expected %s to contain %s" % [str(container), str(value)])


func _record(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		_failures.append("%s (%s)" % [label, detail])


func get_results() -> Dictionary:
	return {"passed": _passed, "failed": _failed, "failures": _failures}
