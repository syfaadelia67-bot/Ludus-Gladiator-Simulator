extends Node

const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")


func run() -> void:
	CombatV1SessionStore.clear_all()
	TournamentManager.import_state({})
	GameState.day = 13
	var runtime = GT1CombatRuntimeScript.new()
	var session := runtime.start_encounter(
		13,
		"player_team",
		[
			_state_1v1("save_player", "save_r1"),
			_state_1v1("save_player", "save_r2"),
			_state_1v1("save_player", "save_r3"),
		],
	)
	session = runtime.advance_exchange(
		session,
		[
			{"actor_id": "save_player", "action_id": "light", "target_id": "save_r1"},
			{"actor_id": "save_r1", "action_id": "block"},
		],
	)
	assert(int(session.get("completed_bouts", -1)) == 1)
	assert(CombatV1SessionStore.set_gt1_session(session))
	var expected_active_loop := (session.get("active_loop", {}) as Dictionary).duplicate(true)

	var payload := SaveManager._build_payload()
	assert(int(payload.get("version", 0)) == 14)
	assert(payload.get("combat_v1_runtime", null) is Dictionary)
	assert(SaveManager._validate_payload(payload))
	var runtime_payload := payload.get("combat_v1_runtime", {}) as Dictionary
	assert(not (runtime_payload.get("gt1_session", {}) as Dictionary).is_empty())

	CombatV1SessionStore.clear_all()
	TournamentManager.import_state({})
	GameState.day = 1
	assert(SaveManager._apply_payload(payload))
	assert(GameState.get_month() == 13)
	var restored := CombatV1SessionStore.get_gt1_session(13)
	assert(int(restored.get("completed_bouts", -1)) == 1)
	assert(restored.get("active_loop", {}) == expected_active_loop)
	var summary := TournamentManager.get_gt1_summary()
	assert(int(summary.get("player_bouts", -1)) == 1)
	assert(int((summary.get("encounter_progress", {}) as Dictionary).get("13", -1)) == 1)

	CombatV1SessionStore.clear_all()
	TournamentManager.import_state({})
	GameState.day = 1
	print("Save v14 Combat V1 runtime roundtrip test passed")


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
