extends Node

## Executes one legacy headless test inside the project context, so every
## autoload declared in project.godot is available to the test script.
##
## Usage:
##   godot --headless --path game -- --test=res://tests/example_test.gd

const TEST_ARGUMENT_PREFIX := "--test="
const FALLBACK_TIMEOUT_FRAMES := 300

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
	if not ResourceLoader.exists(_test_path):
		_fail("Test script not found: %s" % _test_path)
		return

	var test_script := load(_test_path) as Script
	if test_script == null:
		_fail("Could not load test script: %s" % _test_path)
		return
	var test_instance: Variant = test_script.new()
	if test_instance is Node:
		var test_node := test_instance as Node
		add_child(test_node)
		if test_node.has_method("run"):
			test_node.call("run")
			await get_tree().process_frame
			print("COMPLETED: %s" % _test_path)
			get_tree().quit(0)
			return
	else:
		_fail("Test script must extend Node: %s" % _test_path)
		return

	for _frame in FALLBACK_TIMEOUT_FRAMES:
		await get_tree().process_frame

	print("COMPLETED: %s" % _test_path)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
