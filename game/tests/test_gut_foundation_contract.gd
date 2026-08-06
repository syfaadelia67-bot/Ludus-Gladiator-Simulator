extends Node

const EXPECTED_GUT_VERSION := "9.5.0"
const EXPECTED_GUT_COMMIT := "8255c6305761754748f9fd641da5fd8f51c1708a"
const TEMPLATE_PATHS: Array[String] = [
    "res://tests/gut_templates/unit/test_save_system.gd.in",
    "res://tests/gut_templates/unit/test_economy_system.gd.in",
    "res://tests/gut_templates/unit/test_calendar_system.gd.in",
    "res://tests/gut_templates/unit/test_campaign_system.gd.in",
    "res://tests/gut_templates/unit/test_localization_system.gd.in",
    "res://tests/gut_templates/unit/test_gladiator_model.gd.in",
    "res://tests/gut_templates/integration/test_scene_smoke.gd.in"
]

func run() -> void:
    var lock_data := _read_json("res://tools/gut.lock.json")
    var config_data := _read_json("res://.gutconfig.json")
    var windows_installer := FileAccess.get_file_as_string("res://tools/install_gut_9_5.ps1")
    var unix_installer := FileAccess.get_file_as_string("res://tools/install_gut_9_5.sh")
    var windows_runner := FileAccess.get_file_as_string("res://tools/run_gut.ps1")
    var unix_runner := FileAccess.get_file_as_string("res://tools/run_gut.sh")
    var wrapper := FileAccess.get_file_as_string("res://tools/ludus_gut_cmdln.gd")
    var project_text := FileAccess.get_file_as_string("res://project.godot")
    var repository_root := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\").get_base_dir()
    var gitignore := FileAccess.get_file_as_string(repository_root.path_join(".gitignore"))

    assert(str(lock_data.get("version", "")) == EXPECTED_GUT_VERSION)
    assert(str(lock_data.get("commit", "")) == EXPECTED_GUT_COMMIT)
    assert(str(lock_data.get("install_path", "")) == "res://addons/gut")
    assert(str(lock_data.get("template_path", "")) == "res://tests/gut_templates")
    assert(str(lock_data.get("generated_test_path", "")) == "res://gut_tests")
    assert(str(lock_data.get("archive_url", "")).contains(EXPECTED_GUT_COMMIT))

    assert(config_data.get("dirs", []) == ["res://gut_tests/unit", "res://gut_tests/integration"])
    assert(bool(config_data.get("include_subdirs", false)))
    assert(str(config_data.get("prefix", "")) == "test_")
    assert(str(config_data.get("suffix", "")) == ".gd")
    assert(str(config_data.get("double_strategy", "")) == "SCRIPT_ONLY")
    assert(not bool(config_data.get("no_error_tracking", true)))
    assert(config_data.get("failure_error_types", []) == ["engine", "gut", "push_error"])
    assert(str(config_data.get("junit_xml_file", "")) == "res://test-results/gut.xml")
    assert(not bool(config_data.get("hide_orphans", true)))

    for installer_text in [windows_installer, unix_installer]:
        assert(installer_text.contains(EXPECTED_GUT_VERSION) or installer_text.contains("gut.lock.json"))
        assert(installer_text.contains("plugin.cfg"))
        assert(installer_text.contains("gut_templates"))
        assert(installer_text.contains("gut_tests"))
        assert(not installer_text.contains("tests/gut\""), "Los tests generados no deben quedar bajo el árbol legacy res://tests.")

    assert(windows_runner.contains("install_gut_9_5.ps1"))
    assert(windows_runner.contains("tools/ludus_gut_cmdln.gd"))
    assert(windows_runner.contains("--headless"))
    assert(windows_runner.contains("--import"))
    assert(windows_runner.contains("Start-Process"))
    assert(windows_runner.contains("-PassThru"))
    assert(windows_runner.contains("WaitForExit"))
    assert(windows_runner.contains("ImportTimeoutSeconds"))
    assert(windows_runner.contains("GutTimeoutSeconds"))
    assert(windows_runner.contains("ExitCode = 124"))
    assert(windows_runner.contains("process.ExitCode"))
    assert(windows_runner.contains("-RedirectStandardOutput"))
    assert(windows_runner.contains("-RedirectStandardError"))
    assert(windows_runner.contains("gut-console.log"))
    assert(windows_runner.contains("gut.stdout.log"))
    assert(windows_runner.contains("gut.stderr.log"))
    assert(windows_runner.contains("ShowFullOutput"))
    assert(not windows_runner.contains("$LASTEXITCODE"), "El launcher de Windows debe usar el ExitCode del proceso esperado.")
    assert(not windows_runner.contains("\"-d\""), "GUT no debe abrir el debugger interactivo en automatización.")

    assert(unix_runner.contains("install_gut_9_5.sh"))
    assert(unix_runner.contains("tools/ludus_gut_cmdln.gd"))
    assert(unix_runner.contains("--headless"))
    assert(unix_runner.contains("--import"))
    assert(not unix_runner.contains("\n  -d\n"), "GUT no debe abrir el debugger interactivo en Unix.")

    assert(wrapper.begins_with("extends SceneTree"))
    assert(wrapper.contains("PRESENTATION_AUTOLOADS"))
    assert(wrapper.contains("res://addons/gut/version_conversion.gd"))
    assert(wrapper.contains("res://addons/gut/cli/gut_cli.gd"))
    assert(wrapper.contains("loader.restore_ignore_addons()"))

    assert(gitignore.contains("game/addons/gut/"))
    assert(gitignore.contains("game/gut_tests/"))
    assert(gitignore.contains("game/test-results/"))
    assert(not gitignore.contains("game/tests/gut/"))
    assert(not project_text.contains("res://addons/gut/plugin.cfg"), "GUT debe mantenerse como herramienta CLI hasta validar la integración.")

    for template_path in TEMPLATE_PATHS:
        assert(FileAccess.file_exists(template_path), "Falta la plantilla GUT: %s" % template_path)
        var source := FileAccess.get_file_as_string(template_path)
        assert(source.begins_with("extends GutTest"), "%s debe extender GutTest." % template_path)
        assert(source.contains("func test_"), "%s debe contener al menos una prueba GUT." % template_path)
        assert(not source.contains("var translated :="), "%s no debe inferir traducciones desde retornos Variant." % template_path)

    print("GUT 9.5.0 foundation contract: OK · 7 suites bootstrap-managed")

func _read_json(path: String) -> Dictionary:
    assert(FileAccess.file_exists(path), "Falta el archivo JSON: %s" % path)
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    assert(parsed is Dictionary, "El archivo debe contener un objeto JSON válido: %s" % path)
    return parsed as Dictionary if parsed is Dictionary else {}
