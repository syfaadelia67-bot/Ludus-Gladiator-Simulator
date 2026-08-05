extends Node

## Executes tests inside the real project context, so every autoload declared
## in project.godot is available.
##
## Single test (Node tests run inside this process; SceneTree tests are spawned
## with --script automatically):
##   godot --headless --path game -- --test=res://tests/example_test.gd
##
## Complete suite, one isolated Godot process per test:
##   godot --headless --path game -- --test=res://tests/...
##
## CI groups:
##   godot --headless --path game -- --test=res://tests/... --test-group=core
##   godot --headless --path game -- --test=res://tests/... --test-group=ui

const TEST_ARGUMENT_PREFIX := "--test="
const GROUP_ARGUMENT_PREFIX := "--test-group="
const SUITE_SUFFIX := "/..."
const FALLBACK_TIMEOUT_FRAMES := 300
const SUPPORTED_TEST_SUFFIXES: Array[String] = ["_test.gd", "_contract.gd"]

# Every exclusion must include a human-readable reason. The suite contract
# verifies this dictionary so files cannot silently disappear from CI.
const EXCLUDED_TEST_FILES := {
	"test_runner.gd": "Autoload test orchestrator; it is infrastructure, not a test case."
}

# Tests are classified by path. UI markers are intentionally narrow; every
# other discovered test belongs to core, so there is no unassigned state.
const UI_TEST_MARKERS: Array[String] = [
	"screen", "router", "hud", "finca", "market_hub", "barracks_hub",
	"arena_scroll", "relationships", "dossier", "localization"
]

var _test_path := ""
var _test_group := "all"

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(TEST_ARGUMENT_PREFIX):
			_test_path = argument.trim_prefix(TEST_ARGUMENT_PREFIX)
		elif argument.begins_with(GROUP_ARGUMENT_PREFIX):
			_test_group = argument.trim_prefix(GROUP_ARGUMENT_PREFIX).strip_edges().to_lower()
	call_deferred("_run_requested_test")

func _run_requested_test() -> void:
	if _test_path.is_empty():
		return
	if _test_group not in ["all", "core", "ui"]:
		_fail("Unknown test group: %s" % _test_group)
		return
	if _is_suite_request(_test_path):
		_run_suite(_test_path)
		return
	if _requires_script_mode(_test_path):
		_run_external_test(_test_path, true)
		return
	await _run_single_node_test(_test_path)

func _is_suite_request(path: String) -> bool:
	return path.ends_with(SUITE_SUFFIX) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))

func _run_suite(request_path: String) -> void:
	var directory_path := request_path.trim_suffix(SUITE_SUFFIX).trim_suffix("/")
	var test_paths := _discover_tests(directory_path, _test_group)
	if test_paths.is_empty():
		_fail("No test scripts found for group '%s' in: %s" % [_test_group, directory_path])
		return

	print("SUITE START: %d test(s) · group=%s" % [test_paths.size(), _test_group])
	var failures: Array[String] = []
	for test_path in test_paths:
		var exit_code := _execute_isolated_test(test_path)
		if exit_code != 0:
			failures.append("%s (exit %d)" % [test_path, exit_code])
		else:
			print("SUITE PASS: %s" % test_path)

	if not failures.is_empty():
		_fail("Suite failed: %s" % ", ".join(failures))
		return
	print("SUITE COMPLETED: %d/%d passed · group=%s" % [test_paths.size(), test_paths.size(), _test_group])
	get_tree().quit(0)

func _discover_tests(directory_path: String, group: String = "all") -> Array[String]:
	var discovered: Array[String] = []
	_collect_tests(directory_path, discovered)
	var result: Array[String] = []
	for test_path in discovered:
		var assigned_group := _classify_test(test_path)
		if group == "all" or assigned_group == group:
			result.append(test_path)
	result.sort()
	return result

func _collect_tests(directory_path: String, result: Array[String]) -> void:
	var absolute_directory := ProjectSettings.globalize_path(directory_path)
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		var entry_path := "%s/%s" % [directory_path, entry_name]
		if directory.current_is_dir():
			if not entry_name.begins_with("."):
				_collect_tests(entry_path, result)
		elif _is_test_file(entry_name) and not EXCLUDED_TEST_FILES.has(entry_name):
			result.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()

func _is_test_file(file_name: String) -> bool:
	for suffix in SUPPORTED_TEST_SUFFIXES:
		if file_name.ends_with(suffix):
			return true
	return false

func _classify_test(test_path: String) -> String:
	var normalized := test_path.to_lower()
	for marker in UI_TEST_MARKERS:
		if normalized.contains(marker):
			return "ui"
	return "core"

func _requires_script_mode(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var source := FileAccess.get_file_as_string(path)
	for raw_line in source.split("\n"):
		var line := str(raw_line).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		return line.begins_with("extends SceneTree")
	return false

func _execute_isolated_test(path: String) -> int:
	var output: Array = []
	var arguments: Array[String] = [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://")
	]
	if _requires_script_mode(path):
		arguments.append("--script")
		arguments.append(path)
	else:
		arguments.append("--")
		arguments.append("%s%s" % [TEST_ARGUMENT_PREFIX, path])
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	for line in output:
		print(str(line).trim_suffix("\n"))
	return exit_code

func _run_external_test(path: String, quit_after: bool) -> void:
	if not ResourceLoader.exists(path):
		_fail("Test script not found: %s" % path)
		return
	var exit_code := _execute_isolated_test(path)
	if quit_after:
		get_tree().quit(exit_code)

func _run_single_node_test(path: String) -> void:
	if not ResourceLoader.exists(path):
		_fail("Test script not found: %s" % path)
		return

	var test_script := load(path) as Script
	if test_script == null:
		_fail("Could not load test script: %s" % path)
		return
	var test_instance: Variant = test_script.new()
	if not test_instance is Node:
		_fail("Test script must extend Node or SceneTree: %s" % path)
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

	_fail("Test did not complete or call get_tree().quit(): %s" % path)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
