extends Node


func _ready() -> void:
	var game_state := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	var planning := FileAccess.get_file_as_string(
		"res://scripts/systems/weekly_planning_controller.gd"
	)
	var policy := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_turn_closure_policy.gd"
	)

	_assert_single_closure_authority(game_state, planning, policy)
	_assert_processing_order(game_state)
	_assert_non_gt_fail_open_boundary(policy)
	print("Monthly turn closure authority: OK")
	get_tree().quit(0)


func _assert_single_closure_authority(game_state: String, planning: String, policy: String) -> void:
	assert(game_state.contains("func get_month_closure_status()"))
	assert(game_state.contains("var closure_status := get_month_closure_status()"))
	assert(game_state.contains("campaign_action_blocked.emit(reason)"))
	assert(planning.contains("GameState.get_month_closure_status()"))
	assert(not planning.contains("blockers.append("))
	assert(policy.contains('BLOCKER_CAMPAIGN_OVER := "campaign_over"'))
	assert(policy.contains('BLOCKER_EVENT_PENDING := "event_pending"'))
	assert(policy.contains('BLOCKER_GT1_INCOMPLETE := "gt1_encounter_incomplete"'))


func _assert_processing_order(game_state: String) -> void:
	var roster_pos := game_state.find("RosterManager.process_month()")
	var rivals_pos := game_state.find("RivalManager.process_month()")
	var economy_pos := game_state.find("EconomyManager.process_month()")
	var tournaments_pos := game_state.find("TournamentManager.process_month()")
	var clock_pos := game_state.find("day += 1")
	var events_pos := game_state.find("EventManager.process_month()")
	var food_pos := game_state.find("food = maxi(0, food - monthly_consumption)")
	for position in [
		roster_pos,
		rivals_pos,
		economy_pos,
		tournaments_pos,
		clock_pos,
		events_pos,
		food_pos,
	]:
		assert(position >= 0)
	assert(roster_pos < rivals_pos)
	assert(rivals_pos < economy_pos)
	assert(economy_pos < tournaments_pos)
	assert(tournaments_pos < clock_pos)
	assert(clock_pos < events_pos)
	assert(events_pos < food_pos)


func _assert_non_gt_fail_open_boundary(policy: String) -> void:
	assert(policy.contains('"non_gt_combat_required": false'))
	assert(policy.contains('"legacy_combat_schedule_allowed": false'))
	assert(policy.contains('"warnings_block_closure": false'))
	assert(not policy.contains("CombatManager"))
