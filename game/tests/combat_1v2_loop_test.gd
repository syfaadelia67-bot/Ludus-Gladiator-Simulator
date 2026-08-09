extends SceneTree

const Combat1v2LoopScript = preload("res://scripts/combat/combat_1v2_loop.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_requires_three_active_intents_initially()
	_test_partial_ko_continues_with_survivors_only()
	_test_knocked_out_fighter_cannot_submit_next_exchange()
	_test_second_enemy_ko_finishes_combat()
	_test_non_1v2_is_rejected()

	if _failures.is_empty():
		print("Combat 1v2 loop: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_requires_three_active_intents_initially() -> void:
	var loop = Combat1v2LoopScript.new()
	var session: Dictionary = loop.start(_state(100, 12, 100, 100))
	var result: Dictionary = (
		loop
		. advance(
			session,
			[
				{"actor_id": "a", "action_id": "light", "target_id": "b1"},
				{"actor_id": "b1", "action_id": "block"},
			],
		)
	)
	_assert_eq(result.get("status"), "rejected", "initial 1v2 exchange needs all three intents")
	_assert_eq(result.get("reason"), "incomplete_exchange", "missing third intent must be explicit")


func _test_partial_ko_continues_with_survivors_only() -> void:
	var loop = Combat1v2LoopScript.new()
	var session: Dictionary = loop.start(_state(100, 12, 5, 100))
	_assert_eq(session.get("status"), "running", "valid 1v2 must start running")

	var first: Dictionary = _ko_first_enemy(loop, session)
	_assert_eq(first.get("status"), "running", "partial team KO must not finish 1v2")
	_assert_eq(first.get("outcome"), "ongoing", "one surviving enemy keeps combat ongoing")
	_assert_true((first.get("ko_fighter_ids", []) as Array).has("b1"), "first enemy must be KO")
	_assert_eq(first.get("combat_end_resolved"), false, "partial KO must not resolve combat end")

	var second: Dictionary = (
		loop
		. advance(
			first,
			[
				{"actor_id": "a", "action_id": "block"},
				{"actor_id": "b2", "action_id": "light", "target_id": "a"},
			],
		)
	)
	_assert_eq(second.get("status"), "running", "next exchange must require survivors only")
	_assert_eq(second.get("exchange_index"), 2, "survivor exchange must resolve normally")
	var b1: Dictionary = _fighter_by_id(second.get("state", {}) as Dictionary, "b1")
	_assert_eq(float(b1.get("current_pv", -1.0)), 0.0, "KO fighter must remain at zero PV")

	var contract: Dictionary = loop.get_contract()
	_assert_eq(
		contract.get("partial_team_ko"),
		"combat_continues_while_team_has_active_fighter",
		"1v2 must end only when the team is eliminated",
	)
	_assert_eq(
		contract.get("winner_authority"),
		"combat_simulator",
		"1v2 loop must not own winner selection",
	)


func _test_knocked_out_fighter_cannot_submit_next_exchange() -> void:
	var loop = Combat1v2LoopScript.new()
	var session: Dictionary = loop.start(_state(100, 12, 5, 100))
	var first: Dictionary = _ko_first_enemy(loop, session)
	var result: Dictionary = (
		loop
		. advance(
			first,
			[
				{"actor_id": "a", "action_id": "block"},
				{"actor_id": "b1", "action_id": "block"},
				{"actor_id": "b2", "action_id": "light", "target_id": "a"},
			],
		)
	)
	_assert_eq(result.get("status"), "rejected", "KO fighter intent must fail closed")
	_assert_eq(result.get("reason"), "inactive_actor_intent", "KO actor rejection must be explicit")


func _test_second_enemy_ko_finishes_combat() -> void:
	var loop = Combat1v2LoopScript.new()
	var session: Dictionary = loop.start(_state(100, 12, 5, 5))
	var first: Dictionary = _ko_first_enemy(loop, session)
	_assert_eq(first.get("status"), "running", "first enemy KO must leave second enemy active")

	var result: Dictionary = (
		loop
		. advance(
			first,
			[
				{"actor_id": "a", "action_id": "heavy", "target_id": "b2"},
				{"actor_id": "b2", "action_id": "block"},
			],
		)
	)
	_assert_eq(result.get("status"), "combat_finished", "second enemy KO must finish 1v2")
	_assert_eq(result.get("outcome"), "team_win", "surviving solo team must win")
	_assert_eq(result.get("winner_team_id"), "alpha", "alpha must be authoritative winner")
	_assert_eq(result.get("loser_team_id"), "beta", "eliminated beta team must lose")
	_assert_eq(result.get("combat_end_resolved"), true, "team elimination must resolve combat end")


func _test_non_1v2_is_rejected() -> void:
	var loop = Combat1v2LoopScript.new()
	var state := _state(100, 12, 100, 100)
	state["format"] = "1v1"
	(state["fighters"] as Array).pop_back()
	var result: Dictionary = loop.start(state)
	_assert_eq(result.get("status"), "rejected", "1v2 loop must reject other formats")
	_assert_eq(result.get("reason"), "unsupported_format", "format rejection must be explicit")


func _ko_first_enemy(loop, session: Dictionary) -> Dictionary:
	return (
		loop
		. advance(
			session,
			[
				{"actor_id": "a", "action_id": "heavy", "target_id": "b1"},
				{"actor_id": "b1", "action_id": "block"},
				{"actor_id": "b2", "action_id": "block"},
			],
		)
	)


func _state(alpha_pv: int, alpha_power: int, b1_pv: int, b2_pv: int) -> Dictionary:
	return {
		"format": "1v2",
		"fighters":
		[
			_fighter("a", "alpha", alpha_pv, alpha_power),
			_fighter("b1", "beta", b1_pv, 0),
			_fighter("b2", "beta", b2_pv, 0),
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


func _fighter_by_id(state: Dictionary, fighter_id: String) -> Dictionary:
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("id", "")) == fighter_id:
			return fighter.duplicate(true)
	return {}


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
