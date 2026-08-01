extends Node

## Executes tests inside the real project context, so every autoload declared
## in project.godot is available.
##
## Single test:
##   godot --headless --path game -- --test=res://tests/example_test.gd
##
## Complete suite, one isolated Godot process per test:
##   godot --headless --path game -- --test=res://tests/...

const TEST_ARGUMENT_PREFIX := "--test="
const SUITE_SUFFIX := "/..."
const FALLBACK_TIMEOUT_FRAMES := 300
const EXCLUDED_TEST_FILES := ["test_runner.gd"]

var _test_path := ""

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(TEST_ARGUMENT_PREFIX):
			_test_path = argument.trim_prefix(TEST_ARGUMENT_PREFIX)
			break
	call_deferred("_run_requested_test")

func _run_requested_test() -> void:
	if _test_path.is_empty():
		return
	if _is_suite_request(_test_path):
		_run_suite(_test_path)
		return
	await _run_single_test(_test_path)

func _is_suite_request(path: String) -> bool:
	return path.ends_with(SUITE_SUFFIX) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))

func _run_suite(request_path: String) -> void:
	var directory_path := request_path.trim_suffix(SUITE_SUFFIX).trim_suffix("/")
	var test_paths := _discover_tests(directory_path)
	if test_paths.is_empty():
		_fail("No test scripts found in: %s" % directory_path)
		return

	print("SUITE START: %d test(s)" % test_paths.size())
	var failures: Array[String] = []
	for test_path in test_paths:
		var output: Array = []
		var arguments := [
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--",
			"%s%s" % [TEST_ARGUMENT_PREFIX, test_path]
		]
		var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
		for line in output:
			print(str(line).trim_suffix("\n"))
		if exit_code != 0:
			failures.append("%s (exit %d)" % [test_path, exit_code])
		else:
			print("SUITE PASS: %s" % test_path)

	if not failures.is_empty():
		_fail("Suite failed: %s" % ", ".join(failures))
		return
	print("SUITE COMPLETED: %d/%d passed" % [test_paths.size(), test_paths.size()])
	get_tree().quit(0)

func _discover_tests(directory_path: String) -> Array[String]:
	var absolute_directory := ProjectSettings.globalize_path(directory_path)
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		return []
	var result: Array[String] = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with("_test.gd") and file_name not in EXCLUDED_TEST_FILES:
			result.append("%s/%s" % [directory_path, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result

func _run_single_test(path: String) -> void:
	if not ResourceLoader.exists(path):
		_fail("Test script not found: %s" % path)
		return

	var test_script := load(path) as Script
	if test_script == null:
		_fail("Could not load test script: %s" % path)
		return
	var test_instance: Variant = test_script.new()
	if not test_instance is Node:
		_fail("Test script must extend Node: %s" % path)
		return

	var test_node := test_instance as Node
	add_child(test_node)
	if test_node.has_method("run"):
		test_node.call("run")
		await get_tree().process_frame
		print("COMPLETED: %s" % path)
		get_tree().quit(0)
		return

	for _frame in FALLBACK_TIMEOUT_FRAMES:
		await get_tree().process_frame

	print("COMPLETED: %s" % path)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
