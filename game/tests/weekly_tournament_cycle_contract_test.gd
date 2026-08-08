extends Node


func run() -> void:
	var manager_source := FileAccess.get_file_as_string(
		"res://scripts/systems/tournament_manager_weekly.gd"
	)
	var game_state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	var panel_source := FileAccess.get_file_as_string("res://scripts/ui/tournaments_panel.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")

	assert(manager_source.contains("const GT1_ENCOUNTER_MONTHS := [13, 16, 20]"))
	assert(manager_source.contains("const GT1_TOTAL_BOUTS := 9"))
	assert(manager_source.contains("const GT1_POINTS_PER_WIN := 3"))
	assert(manager_source.contains("func process_month() -> Array:"))
	assert(manager_source.contains("func process_week() -> Array:\n\treturn process_month()"))
	assert(manager_source.contains("scheduled_month"))
	assert(manager_source.contains("accepted_month"))
	assert(manager_source.contains("resolved_month"))
	assert(manager_source.contains("_migrate_month_fields"))
	assert(manager_source.contains("_has_second_official"))
	assert(manager_source.contains("rng.randf() < 0.40"))

	assert(game_state_source.contains("TournamentManager.process_month()"))
	assert(game_state_source.contains("TournamentManager.prepare_month(get_month())"))
	assert(not game_state_source.contains("TournamentManager.process_day()"))
	assert(
		project_source.contains(
			'TournamentManager="*res://scripts/systems/tournament_manager_weekly.gd"'
		)
	)

	assert(panel_source.contains("Mes %d"))
	assert(panel_source.contains("Mes programado"))
	assert(panel_source.contains("_scheduled_month"))
	assert(not panel_source.contains("Semana programada"))

	print("PASS: monthly tournament cycle contract")
