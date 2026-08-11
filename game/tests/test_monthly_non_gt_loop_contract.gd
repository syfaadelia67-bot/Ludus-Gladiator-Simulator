extends Node


func _ready() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var wrapper := FileAccess.get_file_as_string(
		"res://scripts/systems/tournament_manager_demo_monthly.gd"
	)
	var campaign := FileAccess.get_file_as_string("res://scripts/systems/campaign_manager_demo.gd")
	var policy := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_non_gt_activity_policy.gd"
	)
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

	assert(policy.contains('"non_gt_mode": "management_only"'))
	assert(policy.contains('"demo_loop_frozen": true'))
	assert(policy.contains('"full_game_non_gt_arena_deferred": true'))
	assert(policy.contains('"replacement_objectives_required": false'))
	assert(policy.contains("RETIRED_DEMO_OBJECTIVES"))

	assert(not campaign.contains("CombatManager.combat_finished.connect"))
	assert(campaign.contains("_sync_approved_combat_progress"))
	assert(campaign.contains('summary.get("player_bouts", 0)'))
	assert(campaign.contains('summary.get("player_wins", 0)'))
	assert(campaign.contains("is_objective_retired_from_demo"))
	assert(campaign.contains('data["design_blocked"] = false'))
	assert(campaign.contains('data["available"] = true'))
	assert(campaign.contains('data["unlock_status"] = "demo_gt1_only"'))

	assert(objectives.contains('"ruins": "basic_preparation"'))
	assert(objectives.contains('"blood_reputation": "recognized_house"'))
	assert(objectives.contains("GameState.month_advanced.connect"))
	assert(not objectives.contains("GameState.week_advanced.connect"))
	assert(not objectives.contains("CombatManager.get_event_name_for_week"))
	assert(objectives.contains("func get_month_markers"))
	assert(presenter.contains("Plazo:[/b] mes"))
	assert(presenter.contains("Mes %d · %s"))

	print("Monthly non-GT demo loop contract: OK")
	get_tree().quit(0)
