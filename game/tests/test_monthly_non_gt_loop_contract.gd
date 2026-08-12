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
	var arena_runtime := FileAccess.get_file_as_string(
		"res://scripts/combat/monthly_arena_combat_runtime.gd"
	)
	var arena_screen := FileAccess.get_file_as_string("res://scripts/ui/arena_screen_monthly.gd")

	assert(
		project.contains(
			'TournamentManager="*res://scripts/systems/tournament_manager_demo_monthly.gd"'
		)
	)
	assert(wrapper.contains("func _build_canonical_month_schedule"))
	assert(wrapper.contains("_build_underworld_event(month)"))
	assert(wrapper.contains("_build_minor_event(month, 1)"))
	assert(wrapper.contains("_build_gt1_event(month)"))
	assert(wrapper.contains("CANONICAL_COMPETITIONS"))
	assert(wrapper.contains("func accept_event_team"))
	assert(wrapper.contains("func get_active_contract_for_event"))
	assert(wrapper.contains("return super.register_combat_result(fighter_id, victory)"))
	assert(wrapper.contains("return super.process_month()"))
	assert(not wrapper.contains("_quarantine_legacy_non_gt_contracts"))

	assert(policy.contains('"non_gt_mode": "management_plus_arena"'))
	assert(policy.contains('"non_gt_combat_optional": true'))
	assert(policy.contains('"underworld_available_every_month": true'))
	assert(policy.contains('"official_minor_available_on_non_gt_months": true'))
	assert(policy.contains('"full_game_non_gt_arena_deferred": false'))
	assert(policy.contains("CANONICAL_NON_GT_COMPETITIONS"))
	assert(policy.contains('"campaign_combat_progress_source": "gt1_combat_v1"'))
	assert(policy.contains('"replacement_objectives_required": false'))
	assert(policy.contains("RETIRED_DEMO_OBJECTIVES"))

	assert(arena_runtime.contains('const CANONICAL_RIVAL_TEAM_ID := "rival_team"'))
	assert(arena_runtime.contains("var opponent_team_id := CANONICAL_RIVAL_TEAM_ID"))
	assert(not arena_runtime.contains('"rival_monthly"'))
	assert(arena_screen.contains("_series_setup_panel.visible = has_tournament_of_mars"))
	assert(arena_screen.contains("TournamentManager.get_gt1_encounter"))

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

	print("Monthly non-GT Arena loop contract: OK")
	get_tree().quit(0)
