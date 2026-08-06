extends SceneTree

const TEST_RUNNER_SCRIPT := preload("res://tests/test_runner.gd")
const GROUP_ARGUMENT_PREFIX := "--test-group="
const TEST_PATH_PREFIX := "TEST_PATH: "

func _init() -> void:
    var group := "all"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with(GROUP_ARGUMENT_PREFIX):
            group = argument.trim_prefix(GROUP_ARGUMENT_PREFIX).strip_edges().to_lower()

    if group not in ["all", "core", "ui"]:
        push_error("Unknown test group: %s" % group)
        quit(2)
        return

    var runner := TEST_RUNNER_SCRIPT.new()
    var test_paths: Array[String] = runner._discover_tests("res://tests", group)
    runner.free()

    if test_paths.is_empty():
        push_error("No tests discovered for group: %s" % group)
        quit(1)
        return

    print("TEST LIST START: %d test(s) · group=%s" % [test_paths.size(), group])
    for test_path in test_paths:
        print("%s%s" % [TEST_PATH_PREFIX, test_path])
    print("TEST LIST COMPLETED: %d test(s) · group=%s" % [test_paths.size(), group])
    quit(0)
