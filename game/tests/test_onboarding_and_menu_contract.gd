extends Node

const TUTORIAL_PATH := "res://scripts/ui/tutorial_controller.gd"
const START_SCREEN_PATH := "res://scripts/ui/start_screen_controller.gd"
const RETURN_MENU_PATH := "res://scripts/ui/main_menu_return_controller.gd"
const PROJECT_PATH := "res://project.godot"

func _ready() -> void:
    _assert_file_contains(TUTORIAL_PATH, [
        "advance_week",
        "obtain_equipment",
        "resolve_event",
        "weekly_combat",
        "GameState.week_advanced",
        "CombatManager.combat_finished"
    ])
    _assert_file_contains(START_SCREEN_PATH, [
        "func show_main_menu()",
        "func _enter_campaign()",
        "overlay.visible = false",
        "LudusOwnerManager.reset_profile()"
    ])
    _assert_file_contains(RETURN_MENU_PATH, [
        "Guardar y menú",
        "SaveManager.save_game()",
        "StartScreenController.show_main_menu()"
    ])
    _assert_file_contains(PROJECT_PATH, [
        "MainMenuReturnController=\"*res://scripts/ui/main_menu_return_controller.gd\""
    ])
    print("Onboarding and menu return contract: OK")
    get_tree().quit()

func _assert_file_contains(path: String, expected_fragments: Array[String]) -> void:
    assert(FileAccess.file_exists(path), "Falta el archivo requerido: %s" % path)
    var file := FileAccess.open(path, FileAccess.READ)
    assert(file != null, "No se pudo abrir: %s" % path)
    var source := file.get_as_text()
    file.close()
    for fragment in expected_fragments:
        assert(source.contains(fragment), "%s no contiene el contrato esperado: %s" % [path, fragment])
