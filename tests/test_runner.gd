## Headless test runner. Discovers every tests/test_*.gd file, instantiates
## it, runs each of its test_* methods, and prints a summary.
##
## Usage: godot --headless --script res://tests/test_runner.gd
## Exits with code 0 if all tests passed, 1 otherwise.
extends SceneTree


func _initialize() -> void:
	var dir := DirAccess.open("res://tests")
	if dir == null:
		push_error("Cannot open res://tests directory")
		quit(1)
		return

	var test_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd" and file_name != "test_runner.gd":
			test_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	test_files.sort()

	var total_passed := 0
	var total_failed := 0
	var all_failures: Array[String] = []

	for test_file in test_files:
		var test_script: Script = load("res://tests/%s" % test_file)
		var instance: Object = test_script.new()
		if not (instance is TestCase):
			push_warning("%s does not extend TestCase, skipping" % test_file)
			continue

		var test_method_names: Array[String] = []
		for method_info in instance.get_method_list():
			var method_name: String = method_info.name
			if method_name.begins_with("test_"):
				test_method_names.append(method_name)
		test_method_names.sort()

		for method_name in test_method_names:
			instance.callv(method_name, [])

		var results: Dictionary = instance.get_results()
		var passed: int = results["passed"]
		var failed: int = results["failed"]
		total_passed += passed
		total_failed += failed
		for failure: String in results["failures"]:
			all_failures.append("%s :: %s" % [test_file, failure])

		print("%s: %d passed, %d failed" % [test_file, passed, failed])

	print("----")
	print("TOTAL: %d passed, %d failed" % [total_passed, total_failed])
	if total_failed > 0:
		print("Failures:")
		for failure in all_failures:
			print(" - %s" % failure)

	quit(1 if total_failed > 0 else 0)
