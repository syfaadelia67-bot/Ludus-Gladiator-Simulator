extends Node

func run() -> void:
    var rival_source := FileAccess.get_file_as_string("res://scripts/systems/rival_manager_weekly.gd")
    var game_state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    _assert(rival_source.contains("func process_week()"), "Rivales debe exponer procesamiento semanal canónico.")
    _assert(rival_source.contains("weekly_rivalry_processed"), "Debe emitir un informe semanal de rivalidad.")
    _assert(rival_source.contains("result[\"week\"]"), "Las operaciones deben registrar la semana.")
    _assert(rival_source.contains("event[\"week\"]"), "Las represalias deben registrar la semana.")
    _assert(rival_source.contains("func process_day()") and rival_source.contains("return process_week()"), "Debe conservarse el alias diario compatible.")
    _assert(game_state_source.contains("RivalManager.process_week()"), "GameState debe usar el ciclo rival semanal.")
    _assert(not game_state_source.contains("RivalManager.process_day()"), "GameState no debe usar el alias diario rival.")
    _assert(project_source.contains("RivalManager=\"*res://scripts/systems/rival_manager_weekly.gd\""), "El manager rival semanal debe estar activo.")

    print("weekly_rival_cycle_contract_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("weekly_rival_cycle_contract_test: %s" % message)
        assert(condition, message)
