extends Node

const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")


func run() -> void:
	_test_month_13_consecutive_1v1_carries_player_state()
	_test_month_16_uses_three_independent_1v1_fights()
	_test_month_20_runs_2v2_series_with_one_substitution()
	_test_month_13_rejects_roster_change()
	_test_month_20_rejects_second_substitution()
	print("GT I real combat runtime tests passed")


func _test_month_13_consecutive_1v1_carries_player_state() -> void:
	TournamentManager.import_state({})
	var runtime = GT1CombatRuntimeScript.new()
	var states: Array = [
		_state_1v1("player", "r13_1"),
		_state_1v1("player", "r13_2"),
		_state_1v1("player", "r13_3"),
	]
	var session: Dictionary = runtime.start_encounter(13, "player_team", states)
	assert(session.get("status") == "combat_running")

	for bout in range(3):
		var enemy_id := "r13_%d" % [bout + 1]
		session = runtime.advance_exchange(
			session,
			[
				{"actor_id": "player", "action_id": "light", "target_id": enemy_id},
				{"actor_id": enemy_id, "action_id": "block"},
			],
		)
		if bout < 2:
			assert(session.get("status") == "combat_running")
			assert((session.get("carried_fighter_ids", []) as Array).has("player"))
		else:
			assert(session.get("status") == "encounter_finished")

	assert(int(session.get("completed_bouts", 0)) == 3)
	assert(int(session.get("player_wins", 0)) == 3)
	assert(int(session.get("player_points", 0)) == 9)
	var summary := TournamentManager.get_gt1_summary()
	assert(int(summary.get("player_bouts", 0)) == 3)
	assert(int(summary.get("player_points", 0)) == 9)


func _test_month_16_uses_three_independent_1v1_fights() -> void:
	TournamentManager.import_state({})
	var runtime = GT1CombatRuntimeScript.new()
	var states: Array = [
		_state_1v1("p16_1", "r16_1"),
		_state_1v1("p16_2", "r16_2"),
		_state_1v1("p16_3", "r16_3"),
	]
	var session: Dictionary = runtime.start_encounter(16, "player_team", states)
	assert(session.get("status") == "combat_running")

	for bout in range(3):
		var player_id := "p16_%d" % [bout + 1]
		var enemy_id := "r16_%d" % [bout + 1]
		session = runtime.advance_exchange(
			session,
			[
				{"actor_id": player_id, "action_id": "light", "target_id": enemy_id},
				{"actor_id": enemy_id, "action_id": "block"},
			],
		)
		assert((session.get("carried_fighter_ids", []) as Array).is_empty())

	assert(session.get("status") == "encounter_finished")
	assert(int(session.get("player_points", 0)) == 9)
	var contract: Dictionary = runtime.get_contract()
	assert((contract.get("month_16", {}) as Dictionary).get("carryover") == [])


func _test_month_20_runs_2v2_series_with_one_substitution() -> void:
	TournamentManager.import_state({})
	var runtime = GT1CombatRuntimeScript.new()
	var states: Array = [
		_state_2v2(["p1", "p2"], ["r20_1a", "r20_1b"]),
		_state_2v2(["p1", "p3"], ["r20_2a", "r20_2b"]),
		_state_2v2(["p1", "p3"], ["r20_3a", "r20_3b"]),
	]
	var session: Dictionary = runtime.start_encounter(20, "player_team", states)
	assert(session.get("status") == "combat_running")
	assert(bool(session.get("substitution_used", false)))

	for bout in range(3):
		var player_ids: Array[String] = ["p1", "p2"] if bout == 0 else ["p1", "p3"]
		var enemy_ids: Array[String] = [
			"r20_%da" % [bout + 1],
			"r20_%db" % [bout + 1],
		]
		session = runtime.advance_exchange(
			session,
			[
				{"actor_id": player_ids[0], "action_id": "light", "target_id": enemy_ids[0]},
				{"actor_id": player_ids[1], "action_id": "light", "target_id": enemy_ids[1]},
				{"actor_id": enemy_ids[0], "action_id": "block"},
				{"actor_id": enemy_ids[1], "action_id": "block"},
			],
		)
		if bout == 0:
			var carried := session.get("carried_fighter_ids", []) as Array
			assert(carried.has("p1"))
			assert(not carried.has("p2"))
			assert(not carried.has("p3"))
		elif bout == 1:
			var carried := session.get("carried_fighter_ids", []) as Array
			assert(carried.has("p1"))
			assert(carried.has("p3"))

	assert(session.get("status") == "encounter_finished")
	assert(int(session.get("completed_bouts", 0)) == 3)
	assert(int(session.get("player_points", 0)) == 9)


func _test_month_13_rejects_roster_change() -> void:
	TournamentManager.import_state({})
	var runtime = GT1CombatRuntimeScript.new()
	var result: Dictionary = runtime.start_encounter(
		13,
		"player_team",
		[
			_state_1v1("player_a", "enemy_a"),
			_state_1v1("player_b", "enemy_b"),
			_state_1v1("player_a", "enemy_c"),
		],
	)
	assert(result.get("status") == "rejected")
	assert(_contains_error(result, "same player gladiator"))


func _test_month_20_rejects_second_substitution() -> void:
	TournamentManager.import_state({})
	var runtime = GT1CombatRuntimeScript.new()
	var result: Dictionary = runtime.start_encounter(
		20,
		"player_team",
		[
			_state_2v2(["p1", "p2"], ["e1", "e2"]),
			_state_2v2(["p1", "p3"], ["e3", "e4"]),
			_state_2v2(["p1", "p4"], ["e5", "e6"]),
		],
	)
	assert(result.get("status") == "rejected")
	assert(_contains_error(result, "at most one unilateral"))


func _state_1v1(player_id: String, enemy_id: String) -> Dictionary:
	return {
		"format": "1v1",
		"fighters": [
			_fighter(player_id, "player_team", 40, 100),
			_fighter(enemy_id, "rival_team", 5, 0),
		],
	}


func _state_2v2(player_ids: Array[String], enemy_ids: Array[String]) -> Dictionary:
	return {
		"format": "2v2",
		"fighters": [
			_fighter(player_ids[0], "player_team", 40, 100),
			_fighter(player_ids[1], "player_team", 40, 100),
			_fighter(enemy_ids[0], "rival_team", 5, 0),
			_fighter(enemy_ids[1], "rival_team", 5, 0),
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


func _contains_error(result: Dictionary, fragment: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
