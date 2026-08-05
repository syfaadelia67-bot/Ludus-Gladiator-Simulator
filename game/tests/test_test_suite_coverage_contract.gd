extends Node

const TEST_ROOT := "res://tests"
const SUPPORTED_SUFFIXES: Array[String] = ["_test.gd", "_contract.gd"]
const SUPPORTED_PREFIXES: Array[String] = ["test_"]
const EXCLUDED_FILES := {
    "test_runner.gd": "Autoload test orchestrator; it is infrastructure, not a test case."
}
const UI_MARKERS: Array[String] = [
    "screen", "router", "hud", "finca", "presenter", "_ui_", "arena",
    "market_hub", "market_roster", "barracks_hub", "relationships", "dossier",
    "localization", "campaign_panel", "campaign_result", "continue_summary",
    "completed_campaign", "onboarding", "menu", "placeholder_asset"
]
const FAILURE_MARKERS: Array[String] = [
    "SCRIPT ERROR: Assertion failed",
    "SCRIPT ERROR: Parse Error",
    "SCRIPT ERROR: Compile Error",
    "ERROR: Test did not complete or call get_tree().quit()"
]

func _ready() -> void:
    var runner_text := FileAccess.get_file_as_string("res://tests/test_runner.gd")
    var game_root := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
    var repository_root := game_root.get_base_dir()
    var workflow_path := repository_root.path_join(".github/workflows/godot-tests.yml")
    var workflow_text := FileAccess.get_file_as_string(workflow_path)
    var project_text := FileAccess.get_file_as_string("res://project.godot")
    var documentation_text := FileAccess.get_file_as_string("res://tests/TEST_SUITE.md")

    assert(not workflow_text.is_empty(), "Could not read workflow: %s" % workflow_path)
    assert(runner_text.contains("const SUPPORTED_TEST_SUFFIXES: Array[String] = [\"_test.gd\", \"_contract.gd\"]"))
    assert(runner_text.contains("const SUPPORTED_TEST_PREFIXES: Array[String] = [\"test_\"]"))
    assert(runner_text.contains("const FAILURE_OUTPUT_MARKERS"))
    assert(runner_text.contains("func _collect_tests"))
    assert(runner_text.contains("func _requires_script_mode"))
    assert(runner_text.contains("func _line_reports_test_failure"))
    assert(runner_text.contains("output_detected_failure"))
    assert(runner_text.contains("line.begins_with(\"extends SceneTree\")"))
    assert(runner_text.contains("--script"))
    assert(runner_text.contains("--test-group="))
    assert(runner_text.contains("group == \"all\" or assigned_group == group"))
    assert(runner_text.contains("Every exclusion must include a human-readable reason"))
    assert(runner_text.contains("Test did not complete or call get_tree().quit()"))

    for suffix in SUPPORTED_SUFFIXES:
        assert(runner_text.contains("\"%s\"" % suffix))
    for prefix in SUPPORTED_PREFIXES:
        assert(runner_text.contains("\"%s\"" % prefix))
    for marker in UI_MARKERS:
        assert(runner_text.contains("\"%s\"" % marker))
    for failure_marker in FAILURE_MARKERS:
        assert(runner_text.contains("\"%s\"" % failure_marker))
    for file_name in EXCLUDED_FILES.keys():
        var reason := str(EXCLUDED_FILES[file_name]).strip_edges()
        assert(not reason.is_empty())
        assert(runner_text.contains("\"%s\"" % file_name))
        assert(runner_text.contains(reason))

    assert(workflow_text.contains("compile:"))
    assert(workflow_text.contains("core-systems:"))
    assert(workflow_text.contains("ui-contracts:"))
    assert(workflow_text.contains("name: Compile and smoke test"))
    assert(workflow_text.contains("name: Core systems suite"))
    assert(workflow_text.contains("name: UI and integration contracts"))
    assert(workflow_text.contains("--test=res://tests/... --test-group=core"))
    assert(workflow_text.contains("--test=res://tests/... --test-group=ui"))
    assert(workflow_text.contains("version: ${{ env.GODOT_VERSION }}"))
    assert(workflow_text.contains("GODOT_VERSION: 4.5.2"))
    assert(not workflow_text.contains("godot --headless --path game --script res://tests/history_integrity_validator_test.gd"))

    assert(project_text.contains("TestRunner=\"*res://tests/test_runner.gd\""))
    assert(documentation_text.contains("*_test.gd"))
    assert(documentation_text.contains("*_contract.gd"))
    assert(documentation_text.contains("test_*.gd"))
    assert(documentation_text.contains("assertion"))
    assert(documentation_text.contains("No existe un estado sin grupo"))
    assert(documentation_text.contains("No se instala ningún plugin"))

    var scripts: Array[String] = []
    _collect_scripts(TEST_ROOT, scripts)
    assert(not scripts.is_empty())

    var recognized_count := 0
    var core_count := 0
    var ui_count := 0
    var scene_tree_count := 0
    var node_count := 0

    for path in scripts:
        var file_name := path.get_file()
        var looks_like_test := file_name.begins_with("test_") or file_name.contains("_test.") or file_name.contains("_contract.")
        if EXCLUDED_FILES.has(file_name):
            continue
        if not looks_like_test:
            continue

        assert(_is_recognized_test(file_name), "Test script is not discoverable or documented: %s" % path)
        recognized_count += 1
        var group := _classify(path)
        assert(group in ["core", "ui"])
        if group == "ui":
            ui_count += 1
        else:
            core_count += 1

        var base_type := _first_code_line(FileAccess.get_file_as_string(path))
        assert(base_type.begins_with("extends Node") or base_type.begins_with("extends SceneTree"), "Unsupported test base type: %s -> %s" % [path, base_type])
        if base_type.begins_with("extends SceneTree"):
            scene_tree_count += 1
        else:
            node_count += 1

    assert(recognized_count >= 10)
    assert(core_count > 0)
    assert(ui_count > 0)
    assert(scene_tree_count > 0)
    assert(node_count > 0)

    print("Test discovery, isolation and CI group coverage contract: OK · %d tests (%d core, %d UI)" % [recognized_count, core_count, ui_count])
    get_tree().quit(0)

func _collect_scripts(directory_path: String, result: Array[String]) -> void:
    var directory := DirAccess.open(ProjectSettings.globalize_path(directory_path))
    assert(directory != null, "Could not open test directory: %s" % directory_path)
    if directory == null:
        return
    directory.list_dir_begin()
    var entry_name := directory.get_next()
    while not entry_name.is_empty():
        var entry_path := "%s/%s" % [directory_path, entry_name]
        if directory.current_is_dir():
            if not entry_name.begins_with("."):
                _collect_scripts(entry_path, result)
        elif entry_name.ends_with(".gd"):
            result.append(entry_path)
        entry_name = directory.get_next()
    directory.list_dir_end()

func _is_recognized_test(file_name: String) -> bool:
    for prefix in SUPPORTED_PREFIXES:
        if file_name.begins_with(prefix) and file_name.ends_with(".gd"):
            return true
    for suffix in SUPPORTED_SUFFIXES:
        if file_name.ends_with(suffix):
            return true
    return false

func _classify(test_path: String) -> String:
    var normalized := test_path.to_lower()
    for marker in UI_MARKERS:
        if normalized.contains(marker):
            return "ui"
    return "core"

func _first_code_line(source: String) -> String:
    for raw_line in source.split("\n"):
        var line := str(raw_line).strip_edges()
        if line.is_empty() or line.begins_with("#"):
            continue
        return line
    return ""
