extends Node


func run() -> void:
	var legacy_manager_source := FileAccess.get_file_as_string(
		"res://scripts/systems/tournament_manager_weekly.gd"
	)
	var manager_source := FileAccess.get_file_as_string(
		"res://scripts/systems/tournament_manager_demo_monthly.gd"
	)
	var game_state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	var panel_source := FileAccess.get_file_as_string("res://scripts/ui/tournaments_panel.gd")
	var monthly_panel_source := FileAccess.get_file_as_string(
		"res://scripts/ui/tournaments_panel_monthly.gd"
	)
	var project_source := FileAccess.get_file_as_string("res://project.godot")

	assert(legacy_manager_source.contains("const GT1_ENCOUNTER_MONTHS := [13, 16, 20]"))
	assert(legacy_manager_source.contains("const GT1_TOTAL_BOUTS := 9"))
	assert(legacy_manager_source.contains("const GT1_POINTS_PER_WIN := 3"))
	assert(manager_source.contains("func process_month() -> Array:"))
	assert(manager_source.contains("func process_week() -> Array:\n\treturn process_month()"))
	assert(manager_source.contains("func process_day() -> Array:\n\treturn process_month()"))
	assert(manager_source.contains("_build_canonical_month_schedule"))
	assert(manager_source.contains("_build_underworld_event(month)"))
	assert(manager_source.contains("_build_minor_event(month, 1)"))
	assert(manager_source.contains("_build_gt1_event(month)"))
	assert(manager_source.contains("CANONICAL_COMPETITIONS"))
	assert(not manager_source.contains("_quarantine_legacy_non_gt_contracts"))

	assert(game_state_source.contains("TournamentManager.process_month()"))
	assert(game_state_source.contains("TournamentManager.prepare_month(get_month())"))
	assert(not game_state_source.contains("TournamentManager.process_day()"))
	assert(
		project_source.contains(
			'TournamentManager="*res://scripts/systems/tournament_manager_demo_monthly.gd"'
		)
	)

	assert(panel_source.contains("Mes %d"))
	assert(panel_source.contains("Mes programado"))
	assert(panel_source.contains("_scheduled_month"))
	assert(not panel_source.contains("Semana programada"))
	assert(monthly_panel_source.contains('extends "res://scripts/ui/tournaments_panel.gd"'))

	print("PASS: canonical monthly tournament cycle contract")
