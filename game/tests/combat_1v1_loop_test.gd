extends SceneTree

const Combat1v1LoopScript = preload("res://scripts/combat/combat_1v1_loop.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_chains_resolved_state_between_exchanges()
	_test_ko_stops_before_next_exchange()
	_test_incomplete_exchange_is_rejected()
	_test_non_1v1_is_rejected()

	if _failures.is_empty():
		print("Combat 1v1 loop: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_chains_resolved_state_between_exchanges() -> void:
	var loop = Combat1v1LoopScript.new()
	var session: Dictionary = loop.start(_state(100, 12))
	_assert_eq(session.get("status"), "running", "valid 1v1 must start running")

	var first: Dictionary = loop.advance(
		session,
		[
			{"actor_id": "a", "action_id": "light", "target_id": "b"},
			{"actor_id": "b", "action_id": "block"},
		],
	)
	_assert_eq(first.get("status"), "running", "non-KO exchange must continue loop")
	_assert_eq(first.get("exchange_index"), 1, "first exchange must increment index")
	var first_b: Dictionary = _fighter_by_id(first.get("state", {}) as Dictionary, "b")
	var first_current_pv := float(first_b.get("current_pv", 0.0))
	_assert_true(first_current_pv < 100.0, "first exchange must persist resolved PV damage")

	var second: Dictionary = loop.advance(
		first,
		[
			{"actor_id": "a", "action_id": "block"},
			{"actor_id": "b", "action_id": "light", "target_id": "a"},
		],
	)
	_assert_eq(second.get("status"), "running", "second non-KO exchange must continue")
	_assert_eq(second.get("exchange_index"), 2, "second exchange must increment index")
	var second_b: Dictionary = _fighter_by_id(second.get("state", {}) as Dictionary, "b")
	_assert_eq(
		float(second_b.get("current_pv", 0.0)),
		first_current_pv,
		"resolved runtime PV must carry into the next exchange of the same combat",
	)
	var contract: Dictionary = loop.get_contract()
	_assert_eq(
		contract.get("winner_authority"),
		"pending_combat_end_rules",
		"1v1 loop must not invent a winner before combat-end freeze",
	)


func _test_ko_stops_before_next_exchange() -> void:
	var loop = Combat1v1LoopScript.new()
	var session: Dictionary = loop.start(_state(5, 100))
	var result: Dictionary = loop.advance(
		session,
		[
			{"actor_id": "a", "action_id": "heavy", "target_id": "b"},
			{"actor_id": "b", "action_id": "block"},
		],
	)
	_assert_eq(
		result.get("status"),
		"awaiting_combat_end_resolution",
		"KO must stop the loop before another exchange",
	)
	_assert_true(
		(result.get("ko_fighter_ids", []) as Array).has("b"),
		"KO fighter id must be exposed without declaring a winner",
	)
	_assert_eq(result.get("combat_end_resolved"), false, "KO alone must not fake final combat result")
	var cannot_continue: Dictionary = loop.advance(
		result,
		[
			{"actor_id": "a", "action_id": "light", "target_id": "b"},
			{"actor_id": "b", "action_id": "block"},
		],
	)
	_assert_eq(cannot_continue.get("status"), "rejected", "loop must not advance after KO stop")
	_assert_eq(cannot_continue.get("reason"), "invalid_loop_state", "stopped loop must fail closed")


func _test_incomplete_exchange_is_rejected() -> void:
	var loop = Combat1v1LoopScript.new()
	var session: Dictionary = loop.start(_state(100, 12))
	var result: Dictionary = loop.advance(
		session,
		[
			{"actor_id": "a", "action_id": "light", "target_id": "b"},
		],
	)
	_assert_eq(result.get("status"), "rejected", "incomplete 1v1 exchange must fail closed")
	_assert_eq(result.get("reason"), "incomplete_exchange", "missing peer intent must be explicit")


func _test_non_1v1_is_rejected() -> void:
	var loop = Combat1v1LoopScript.new()
	var state := _state(100, 12)
	state["format"] = "1v2"
	(state["fighters"] as Array).append(_fighter("b2", "beta", 100, 12))
	var result: Dictionary = loop.start(state)
	_assert_eq(result.get("status"), "rejected", "1v1 loop must reject other formats")
	_assert_eq(result.get("reason"), "unsupported_format", "format rejection must be explicit")


func _state(pv: int, power: int) -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter("a", "alpha", pv, power),
			_fighter("b", "beta", pv, 0),
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
