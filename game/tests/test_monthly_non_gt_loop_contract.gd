extends Node


func _ready() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var wrapper := FileAccess.get_file_as_string(
		"res://scripts/systems/tournament_manager_demo_monthly.gd"
	)
	var campaign := FileAccess.get_file_as_string("res://scripts/systems/campaign_manager_demo.gd")
	var objectives := FileAccess.get_file_as_string(
		"res://scripts/systems/chapter_objective_controller.gd"
	)
	var presenter := FileAccess.get_file_as_string(
		"res://scripts/ui/chapter_objective_presenter.gd"
	)

	assert(
		project.contains(
			'TournamentManager="*res://scripts/systems/tournament_manager_demo_monthly.gd"'
		)
	)
	assert(wrapper.contains("func _build_canonical_month_schedule"))
	assert(wrapper.contains("return []"))
	assert(wrapper.contains("return [_build_gt1_event(month)]"))
	assert(not wrapper.contains("_build_underworld_event(month)"))
	assert(not wrapper.contains("_build_minor_event(month"))
	assert(wrapper.contains('str(event.get("competition", "")) != "grand_tournament"'))
	assert(wrapper.contains("_quarantine_legacy_non_gt_contracts"))

	assert(not campaign.contains("CombatManager.combat_finished.connect"))
	assert(campaign.contains("_sync_approved_combat_progress"))
	assert(campaign.contains('summary.get("player_bouts", 0)'))
	assert(campaign.contains('summary.get("player_wins", 0)'))
	assert(campaign.contains("is_objective_design_blocked"))
	assert(campaign.contains('data["design_blocked"]'))
	assert(campaign.contains('data["available"] = not design_blocked'))

	assert(objectives.contains("GameState.month_advanced.connect"))
	assert(not objectives.contains("GameState.week_advanced.connect"))
	assert(not objectives.contains("CombatManager.get_event_name_for_week"))
	assert(objectives.contains("func get_month_markers"))
	assert(objectives.contains('return "bloqueado_diseno"'))
	assert(presenter.contains("Plazo:[/b] mes"))
	assert(presenter.contains("Mes %d · %s"))
	assert(presenter.contains('status == "bloqueado_diseno"'))

	print("Monthly non-GT loop contract: OK")
	get_tree().quit(0)
