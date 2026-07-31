extends Node

const START_SCREEN_PATH := "res://scripts/ui/start_screen_controller.gd"
const OWNER_MANAGER_PATH := "res://scripts/systems/ludus_owner_manager.gd"
const PROJECT_PATH := "res://project.godot"

func _ready() -> void:
    var failures: Array[String] = []
    _check_file_contract(START_SCREEN_PATH, [
        "func _show_main_menu()",
        "func _continue_campaign()",
        "func _show_owner_creation()",
        "func _start_new_campaign()",
        "SaveManager.has_save()",
        "SaveManager.load_game()",
        "LudusOwnerManager.configure_owner"
    ], failures)
    _check_file_contract(OWNER_MANAGER_PATH, [
        "const PROFILE_PATH",
        "func reset_profile()",
        "func _save_local_profile()",
        "func _load_local_profile()",
        "func get_origin_ids()"
    ], failures)
    _check_file_contract(PROJECT_PATH, [
        "StartScreenController=\"*res://scripts/ui/start_screen_controller.gd\""
    ], failures)

    var origin_ids := LudusOwnerManager.get_origin_ids()
    if origin_ids.size() < 4:
        failures.append("La creación de campaña necesita al menos cuatro orígenes seleccionables.")
    for origin_id in origin_ids:
        var origin := LudusOwnerManager.get_origin(origin_id)
        if str(origin.get("name", "")).is_empty():
            failures.append("El origen %s no tiene nombre visible." % origin_id)
        if str(origin.get("description", "")).is_empty():
            failures.append("El origen %s no tiene descripción." % origin_id)
        if not origin.get("bonuses", null) is Dictionary:
            failures.append("El origen %s no tiene un diccionario de bonificaciones." % origin_id)

    if failures.is_empty():
        print("PASS: pantalla de inicio, creación de campaña y perfil persistente cumplen el contrato.")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error(failure)
    get_tree().quit(1)

func _check_file_contract(path: String, required_fragments: Array[String], failures: Array[String]) -> void:
    if not FileAccess.file_exists(path):
        failures.append("No existe %s." % path)
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        failures.append("No se pudo abrir %s." % path)
        return
    var contents := file.get_as_text()
    file.close()
    for fragment in required_fragments:
        if contents.find(fragment) < 0:
            failures.append("%s no contiene el contrato requerido: %s" % [path, fragment])
