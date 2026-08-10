extends Node


func _ready() -> void:
	_assert_monthly_scheduler_authority()
	_assert_monthly_consumers()
	_assert_monthly_turn_closure_authority()
	_assert_non_gt_tournament_authority()
	_assert_legacy_entrypoints_are_adapters()
	_assert_social_autoloads_use_monthly_wrappers()
	_assert_roster_training_recovery_authority()
	print("Monthly runtime authority contract: OK")
	get_tree().quit(0)


func _assert_monthly_scheduler_authority() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	for call in [
		"RosterManager.process_month()",
		"RivalManager.process_month()",
		"EconomyManager.process_month()",
		"TournamentManager.process_month()",
		"EventManager.process_month()",
	]:
		assert(source.contains(call), "Canonical month closure must call %s" % call)
	for forbidden in [
		"RosterManager.process_day()",
		"RivalManager.process_week()",
		"EconomyManager.process_week()",
		"EconomyManager.process_day()",
		"EventManager.process_week()",
		"CombatManager.get_current_event_details()",
		"range(DAYS_PER_WEEK)",
	]:
		assert(not source.contains(forbidden), "Month closure must not call %s" % forbidden)
	assert(source.contains('"internal_work_ticks": 1'))
	assert(source.contains("TournamentManager.get_gt1_encounter(get_month())"))
	assert(source.contains('"processing_order": MonthlyTurnClosurePolicyScript.PROCESSING_ORDER'))


func _assert_monthly_consumers() -> void:
	var market := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
	var planning := FileAccess.get_file_as_string(
		"res://scripts/systems/weekly_planning_controller.gd"
	)
	var cycle_ui := FileAccess.get_file_as_string("res://scripts/ui/weekly_cycle_presentation.gd")
	var closure_ui := FileAccess.get_file_as_string("res://scripts/ui/weekly_closure_presenter.gd")
	var calendar_ui := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_calendar_presenter.gd"
	)
	var event_ui := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_event_modal_presenter.gd"
	)

	assert(market.contains("GameState.month_advanced.connect"))
	assert(not market.contains("GameState.week_advanced.connect"))
	assert(planning.contains("EconomyManager.get_monthly_projection()"))
	assert(planning.contains('"month": GameState.get_month()'))
	assert(planning.contains("GameState.get_month_closure_status()"))
	assert(planning.contains("TournamentManager.grand_tournament_changed.connect"))
	assert(not planning.contains("CombatManager.combat_finished.connect"))
	assert(not planning.contains("CombatManager.last_combat_day"))
	assert(not planning.contains("CombatManager.get_current_event_details()"))
	assert(not planning.contains("GameState.DAYS_PER_WEEK"))
	assert(cycle_ui.contains("GameState.month_advanced.connect"))
	assert(cycle_ui.contains("TournamentManager.get_gt1_encounter(month)"))
	assert(not cycle_ui.contains("CombatManager.get_current_event_details()"))
	assert(closure_ui.contains("GameState.advance_month()"))
	assert(calendar_ui.contains("GameState.month_advanced.connect"))
	assert(calendar_ui.contains("DEMO_FINAL_MONTH := 20"))
	assert(event_ui.contains("EVENTO MENSUAL · MES"))


func _assert_monthly_turn_closure_authority() -> void:
	var game_state := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	var policy := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_turn_closure_policy.gd"
	)
	var planning := FileAccess.get_file_as_string(
		"res://scripts/systems/weekly_planning_controller.gd"
	)

	assert(game_state.contains("func get_month_closure_status()"))
	assert(game_state.contains("var closure_status := get_month_closure_status()"))
	assert(game_state.contains('closure_status.get("can_close", false)'))
	assert(game_state.contains("campaign_action_blocked.emit(reason)"))
	assert(policy.contains('BLOCKER_EVENT_PENDING := "event_pending"'))
	assert(policy.contains('BLOCKER_GT1_INCOMPLETE := "gt1_encounter_incomplete"'))
	assert(policy.contains('"non_gt_combat_required": false'))
	assert(policy.contains('"legacy_combat_schedule_allowed": false'))
	assert(policy.contains('"warnings_block_closure": false'))
	assert(planning.contains("var closure := GameState.get_month_closure_status()"))
	assert(planning.contains('"can_close": bool(closure.get("can_close", false))'))
	assert(not planning.contains("blockers.append("))


func _assert_non_gt_tournament_authority() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var tournaments := FileAccess.get_file_as_string(
		"res://scripts/systems/tournament_manager_demo_monthly.gd"
	)
	var campaign := FileAccess.get_file_as_string(
		"res://scripts/systems/campaign_manager_demo.gd"
	)
	assert(
		project.contains(
			'TournamentManager="*res://scripts/systems/tournament_manager_demo_monthly.gd"'
		)
	)
	assert(tournaments.contains("_build_canonical_month_schedule"))
	assert(tournaments.contains("return []"))
	assert(tournaments.contains("return [_build_gt1_event(month)]"))
	assert(not tournaments.contains("_build_underworld_event(month)"))
	assert(not tournaments.contains("_build_minor_event(month"))
	assert(not campaign.contains("CombatManager.combat_finished.connect"))
	assert(campaign.contains("_sync_approved_combat_progress"))


func _assert_legacy_entrypoints_are_adapters() -> void:
	var roster := FileAccess.get_file_as_string("res://scripts/systems/roster_manager.gd")
	var rivals := FileAccess.get_file_as_string("res://scripts/systems/rival_manager_weekly.gd")
	var economy := FileAccess.get_file_as_string("res://scripts/systems/economy_manager_weekly.gd")
	var tournaments := FileAccess.get_file_as_string(
		"res://scripts/systems/tournament_manager_demo_monthly.gd"
	)
	var events := FileAccess.get_file_as_string("res://scripts/systems/event_manager_demo.gd")

	assert(roster.contains("func process_day()"))
	assert(roster.contains("return process_month()"))
	assert(roster.contains("var last_processed_month: int = 0"))
	assert(roster.contains('cached["duplicate_call_ignored"] = true'))
	assert(rivals.contains("func process_week()"))
	assert(rivals.contains("func process_day()"))
	assert(rivals.count("return process_month()") >= 2)
	assert(not rivals.contains("super.process_day()"))
	assert(not rivals.contains("super.run_operation"))
	assert(economy.contains("func process_week()"))
	assert(economy.contains("func process_day()"))
	assert(economy.count("return process_month()") >= 2)
	assert(not economy.contains("super.process_day()"))
	assert(tournaments.contains("func process_week()"))
	assert(tournaments.contains("func process_day()"))
	assert(tournaments.count("return process_month()") >= 2)
	assert(events.contains("func process_week()"))
	assert(events.contains("func process_day()"))
	assert(events.count("return process_month()") >= 2)
	assert(not events.contains("super.process_week()"))


func _assert_social_autoloads_use_monthly_wrappers() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert(
		project.contains(
			'PersonalityManager="*res://scripts/systems/personality_manager_monthly.gd"'
		)
	)
	assert(
		project.contains(
			'RelationshipManager="*res://scripts/systems/relationship_manager_monthly.gd"'
		)
	)


func _assert_roster_training_recovery_authority() -> void:
	var policy := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_roster_work_policy.gd"
	)
	var person := FileAccess.get_file_as_string("res://scripts/entities/person.gd")
	var training := FileAccess.get_file_as_string(
		"res://scripts/systems/gladiator_training_controller.gd"
	)
	var injury := FileAccess.get_file_as_string(
		"res://scripts/systems/gladiator_injury_controller.gd"
	)

	assert(policy.contains("WORK_OUTPUTS_ENABLED := false"))
	assert(policy.contains("TRAINING_PROGRESS_ENABLED := false"))
	assert(policy.contains("FATIGUE_MUTATION_ENABLED := false"))
	assert(policy.contains("INJURY_AUTO_RECOVERY_ENABLED := false"))
	assert(not person.contains("fatigue += 8"))
	assert(not person.contains("fatigue += 7"))
	assert(not person.contains("training += gained"))
	assert(not person.contains("injury_days = maxi(0, injury_days -"))
	assert(not training.contains("GameState.week_advanced.connect"))
	assert(not training.contains("GameState.month_advanced.connect"))
	assert(not training.contains("_calculate_gain"))
	assert(not training.contains("_injury_risk"))
	assert(injury.contains("GameState.month_advanced.connect"))
	assert(not injury.contains("GameState.week_advanced.connect"))
	assert(not injury.contains("CombatManager.combat_finished.connect"))
