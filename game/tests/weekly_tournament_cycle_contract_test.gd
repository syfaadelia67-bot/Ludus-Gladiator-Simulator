extends Node

func run() -> void:
    var manager_source := FileAccess.get_file_as_string("res://scripts/systems/tournament_manager_weekly.gd")
    var game_state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
    var panel_source := FileAccess.get_file_as_string("res://scripts/ui/tournaments_panel.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    assert(manager_source.contains("const WEEK_OFFSETS"))
    assert(manager_source.contains("\"local_bout\": 1"))
    assert(manager_source.contains("\"imperial_trial\": 4"))
    assert(manager_source.contains("func process_week() -> Array:"))
    assert(manager_source.contains("func process_day() -> Array:\n    return process_week()"))
    assert(manager_source.contains("scheduled_week"))
    assert(manager_source.contains("accepted_week"))
    assert(manager_source.contains("resolved_week"))
    assert(manager_source.contains("_migrate_week_fields"))
    assert(manager_source.contains("current_week % CALENDAR_BLOCK_WEEKS == 0"))

    assert(game_state_source.contains("TournamentManager.process_week()"))
    assert(not game_state_source.contains("TournamentManager.process_day()"))
    assert(project_source.contains("TournamentManager=\"*res://scripts/systems/tournament_manager_weekly.gd\""))

    assert(panel_source.contains("Semana %d"))
    assert(panel_source.contains("Semana programada"))
    assert(panel_source.contains("_scheduled_week"))
    assert(not panel_source.contains("Día programado"))

    print("PASS: weekly tournament cycle contract")
