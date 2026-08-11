extends Node

const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")
const Combat1v1LoopScript = preload("res://scripts/combat/combat_1v1_loop.gd")


func run() -> void:
	_test_running_gt1_session_roundtrip_preserves_combat_state()
	_test_legacy_partial_gt1_rolls_back_exact_incomplete_encounter()
	_test_legacy_month_16_recovery_preserves_completed_month_13()
	_test_legacy_recovery_fails_closed_on_history_mismatch()
	_test_tiebreak_and_rematch_sessions_persist()
	_reset_runtime()
	print("Combat V1 Save v14 session store tests passed")


func _test_running_gt1_session_roundtrip_preserves_combat_state() -> void:
	_reset_runtime()
	GameState.day = 13
	var runtime = GT1CombatRuntimeScript.new()
	var session := runtime.start_encounter(
		13,
		"player_team",
		[
			_state_1v1("player", "r13_1"),
			_state_1v1("player", "r13_2"),
			_state_1v1("player", "r13_3"),
		],
	)
	assert(str(session.get("status", "")) == "combat_running")
	session = runtime.advance_exchange(
		session,
		[
			{"actor_id": "player", "action_id": "light", "target_id": "r13_1"},
			{"actor_id": "r13_1", "action_id": "block"},
		],
	)
	assert(int(session.get("completed_bouts", 0)) == 1)
	assert(CombatV1SessionStore.set_gt1_session(session))
	var expected_loop := (session.get("active_loop", {}) as Dictionary).duplicate(true)
	var serialized := CombatV1SessionStore.export_state()
	CombatV1SessionStore.clear_all()
	assert(CombatV1SessionStore.import_state(serialized))
	var restored := CombatV1SessionStore.get_gt1_session(13)
	assert(int(restored.get("completed_bouts", -1)) == 1)
	assert(restored.get("active_loop", {}) == expected_loop)
	assert(int(TournamentManager.get_gt1_summary().get("player_bouts", 0)) == 1)


func _test_legacy_partial_gt1_rolls_back_exact_incomplete_encounter() -> void:
	_reset_runtime()
	GameState.day = 13
	assert(not TournamentManager.register_grand_tournament_fight_result(true, 13).is_empty())
	assert(not TournamentManager.register_grand_tournament_fight_result(false, 13).is_empty())
	assert(int(TournamentManager.get_gt1_summary().get("player_bouts", 0)) == 2)
	assert(CombatV1SessionStore.import_state({}))
	var summary := TournamentManager.get_gt1_summary()
	assert(int((summary.get("encounter_progress", {}) as Dictionary).get("13", -1)) == 0)
	assert(int(summary.get("player_bouts", -1)) == 0)
	assert(int(summary.get("player_wins", -1)) == 0)
	assert(int(summary.get("player_points", -1)) == 0)
	var report := CombatV1SessionStore.get_last_import_report()
	assert(bool(report.get("legacy_partial_gt1_recovered", false)))
	assert((TournamentManager.export_state().get("history", []) as Array).is_empty())


func _test_legacy_month_16_recovery_preserves_completed_month_13() -> void:
	_reset_runtime()
	GameState.day = 13
	assert(not TournamentManager.register_grand_tournament_fight_result(true, 13).is_empty())
	assert(not TournamentManager.register_grand_tournament_fight_result(false, 13).is_empty())
	assert(not TournamentManager.register_grand_tournament_fight_result(true, 13).is_empty())
	GameState.day = 16
	assert(not TournamentManager.register_grand_tournament_fight_result(true, 16).is_empty())
	assert(not TournamentManager.register_grand_tournament_fight_result(false, 16).is_empty())
	assert(CombatV1SessionStore.import_state({}))
	var summary := TournamentManager.get_gt1_summary()
	var progress := summary.get("encounter_progress", {}) as Dictionary
	assert(int(progress.get("13", -1)) == 3)
	assert(int(progress.get("16", -1)) == 0)
	assert(int(summary.get("player_bouts", -1)) == 3)
	assert(int(summary.get("player_wins", -1)) == 2)
	assert(int(summary.get("player_points", -1)) == 6)
	var history := TournamentManager.export_state().get("history", []) as Array
	assert(history.size() == 3)
	for raw_entry in history:
		assert(int((raw_entry as Dictionary).get("month", 0)) == 13)


func _test_legacy_recovery_fails_closed_on_history_mismatch() -> void:
	_reset_runtime()
	GameState.day = 13
	TournamentManager.import_state(
		{
			"history":
			[
				{
					"competition": "grand_tournament",
					"month": 13,
					"bout": 1,
					"victory": true,
					"points_gained": 3,
				}
			],
			"gt1_player_points": 6,
			"gt1_player_wins": 2,
			"gt1_player_bouts": 2,
			"gt1_encounter_progress": {"13": 2, "16": 0, "20": 0},
		}
	)
	assert(not CombatV1SessionStore.import_state({}))
	var summary := TournamentManager.get_gt1_summary()
	assert(int((summary.get("encounter_progress", {}) as Dictionary).get("13", -1)) == 2)
	assert(int(summary.get("player_bouts", -1)) == 2)
	assert(int(summary.get("player_points", -1)) == 6)
	assert((TournamentManager.export_state().get("history", []) as Array).size() == 1)


func _test_tiebreak_and_rematch_sessions_persist() -> void:
	_reset_runtime()
	TournamentManager.import_state(
		{
			"gt1_player_bouts": 9,
			"gt1_tiebreak_required": true,
			"gt1_encounter_progress": {"13": 3, "16": 3, "20": 3},
		}
	)
	var loop := Combat1v1LoopScript.new().start(_state_1v1("player_tb", "rival_tb"))
	var running := {
		"status": "tiebreak_combat_running",
		"active_loop": loop,
		"standings_resolution": {},
	}
	assert(CombatV1SessionStore.set_tiebreak_session(running))
	var exported := CombatV1SessionStore.export_state()
	CombatV1SessionStore.clear_all()
	assert(CombatV1SessionStore.import_state(exported))
	assert(str(CombatV1SessionStore.get_tiebreak_session().get("status", "")) == "tiebreak_combat_running")
	var rematch := {
		"status": "rematch_required",
		"active_loop": {},
		"standings_resolution": {"status": "rematch_required"},
	}
	assert(CombatV1SessionStore.set_tiebreak_session(rematch))
	assert(str(CombatV1SessionStore.get_tiebreak_session().get("status", "")) == "rematch_required")
	assert(CombatV1SessionStore.set_tiebreak_session({"status": "tiebreak_resolved"}))
	assert(CombatV1SessionStore.get_tiebreak_session().is_empty())


func _reset_runtime() -> void:
	CombatV1SessionStore.clear_all()
	TournamentManager.import_state({})
	GameState.day = 1


func _state_1v1(player_id: String, enemy_id: String) -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter(player_id, "player_team", 40, 100),
			_fighter(enemy_id, "rival_team", 5, 0),
		],
	}


func _fighter(fighter_id: String, team_id: String, pv: int, power: int) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": pv},
		"stamina": 10,
		"equipment": {"power": power, "defense": 0},
	}
