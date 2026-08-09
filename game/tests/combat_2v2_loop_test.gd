extends SceneTree

const Combat2v2LoopScript = preload("res://scripts/combat/combat_2v2_loop.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_requires_four_active_intents_initially()
	_test_partial_ko_continues_with_three_survivors()
	_test_cross_team_simultaneous_ko_continues_as_one_vs_one()
	_test_team_elimination_finishes_combat()
	_test_full_simultaneous_elimination_is_double_ko()
	_test_non_2v2_is_rejected()

	if _failures.is_empty():
		print("Combat 2v2 loop: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_requires_four_active_intents_initially() -> void:
	var loop = Combat2v2LoopScript.new()
	var session: Dictionary = loop.start(_state(100, 100, 100, 100, 12, 0, 0, 0))
	var result: Dictionary = loop.advance(
		session,
		[
			{"actor_id": "a1", "action_id": "light", "target_id": "b1"},
			{"actor_id": "a2", "action_id": "block"},
			{"actor_id": "b1", "action_id": "block"},
		],
	)
	_assert_eq(result.get("status"), "rejected", "initial 2v2 exchange needs four intents")
	_assert_eq(result.get("reason"), "incomplete_exchange", "missing fourth intent must be explicit")


func _test_partial_ko_continues_with_three_survivors() -> void:
	var loop = Combat2v2LoopScript.new()
	var session: Dictionary = loop.start(_state(100, 100, 5, 100, 12, 0, 0, 0))
	var first: Dictionary = loop.advance(
		session,
		[
			{"actor_id": "a1", "action_id": "heavy", "target_id": "b1"},
			{"actor_id": "a2", "action_id": "block"},
			{"actor_id": "b1", "action_id": "block"},
			{"actor_id": "b2", "action_id": "block"},
		],
	)
	_assert_eq(first.get("status"), "running", "one KO must not finish a 2v2 team")
	_assert_true((first.get("ko_fighter_ids", []) as Array).has("b1"), "b1 must be KO")
	_assert_eq(first.get("outcome"), "ongoing", "beta still has one active fighter")

	var second: Dictionary = loop.advance(
		first,
		[
			{"actor_id": "a1", "action_id": "block"},
			{"actor_id": "a2", "action_id": "block"},
			{"actor_id": "b2", "action_id": "light", "target_id": "a1"},
		],
	)
	_assert_eq(second.get("status"), "running", "next exchange must require active fighters only")
	_assert_eq(second.get("exchange_index"), 2, "three-survivor exchange must resolve")
	var b1: Dictionary = _fighter_by_id(second.get("state", {}) as Dictionary, "b1")
	_assert_eq(float(b1.get("current_pv", -1.0)), 0.0, "KO fighter must remain at zero PV")

	var invalid: Dictionary = loop.advance(
		first,
		[
			{"actor_id": "a1", "action_id": "block"},
			{"actor_id": "a2", "action_id": "block"},
			{"actor_id": "b1", "action_id": "block"},
			{"actor_id": "b2", "action_id": "block"},
		],
	)
	_assert_eq(invalid.get("status"), "rejected", "KO fighter intent must fail closed")
	_assert_eq(invalid.get("reason"), "inactive_actor_intent", "KO actor rejection must be explicit")


func _test_cross_team_simultaneous_ko_continues_as_one_vs_one() -> void:
	var loop = Combat2v2LoopScript.new()
	var session: Dictionary = loop.start(_state(5, 100, 5, 100, 12, 0, 12, 0))
	var result: Dictionary = loop.advance(
		session,
		[
			{"actor_id": "a1", "action_id": "heavy", "target_id": "b1"},
			{"actor_id": "a2", "action_id": "block"},
			{"actor_id": "b1", "action_id": "heavy", "target_id": "a1"},
			{"actor_id": "b2", "action_id": "block"},
		],
	)
	_assert_eq(result.get("status"), "running", "cross-team partial KOs must keep combat running")
	_assert_true((result.get("ko_fighter_ids", []) as Array).has("a1"), "a1 must be KO")
	_assert_true((result.get("ko_fighter_ids", []) as Array).has("b1"), "b1 must be KO")
	_assert_eq(result.get("outcome"), "ongoing", "one survivor per team must continue")
	_assert_eq(result.get("combat_end_resolved"), false, "cross-team partial KO is not combat end")

	var follow_up: Dictionary = loop.advance(
		result,
		[
			{"actor_id": "a2", "action_id": "block"},
			{"actor_id": "b2", "action_id": "block"},
		],
	)
	_assert_eq(follow_up.get("status"), "running", "2v2 must continue as surviving 1v1")
	_assert_eq(follow_up.get("exchange_index"), 2, "surviving pair must resolve next exchange")
	var contract: Dictionary = loop.get_contract()
	_assert_eq(
		contract.get("cross_team_simultaneous_ko"),
		"commit_both_then_continue_if_each_team_survives",
		"same-phase cross-team KOs must remain simultaneous",
	)


func _test_team_elimination_finishes_combat() -> void:
	var loop = Combat2v2LoopScript.new()
	var session: Dictionary = loop.start(_state(100, 100, 5, 5, 12, 12, 0, 0))
	var result: Dictionary = loop.advance(
		session,
		[
			{"actor_id": "a1", "action_id": "heavy", "target_id": "b1"},
			{"actor_id": "a2", "action_id": "heavy", "target_id": "b2"},
			{"actor_id": "b1", "action_id": "block"},
			{"actor_id": "b2", "action_id": "block"},
		],
	)
	_assert_eq(result.get("status"), "combat_finished", "eliminating both beta fighters must finish")
	_assert_eq(result.get("outcome"), "team_win", "single surviving team must win")
	_assert_eq(result.get("winner_team_id"), "alpha", "alpha must be authoritative winner")
	_assert_eq(result.get("loser_team_id"), "beta", "beta must be authoritative loser")
	_assert_eq(result.get("combat_end_resolved"), true, "team elimination must resolve combat end")


func _test_full_simultaneous_elimination_is_double_ko() -> void:
	var loop = Combat2v2LoopScript.new()
	var session: Dictionary = loop.start(_state(5, 5, 5, 5, 12, 12, 12, 12))
	var result: Dictionary = loop.advance(
		session,
		[
			{"actor_id": "a1", "action_id": "heavy", "target_id": "b1"},
			{"actor_id": "a2", "action_id": "heavy", "target_id": "b2"},
			{"actor_id": "b1", "action_id": "heavy", "target_id": "a1"},
			{"actor_id": "b2", "action_id": "heavy", "target_id": "a2"},
		],
	)
	_assert_eq(result.get("status"), "combat_finished", "full simultaneous elimination must finish")
	_assert_eq(result.get("outcome"), "double_ko", "both teams eliminated must be double_ko")
	_assert_eq(result.get("winner_team_id"), "", "double KO must have no winner")
	_assert_eq(result.get("loser_team_id"), "", "double KO must have no single loser")
	_assert_eq((result.get("ko_fighter_ids", []) as Array).size(), 4, "all four fighters must be KO")


func _test_non_2v2_is_rejected() -> void:
	var loop = Combat2v2LoopScript.new()
	var state := _state(100, 100, 100, 100, 0, 0, 0, 0)
	state["format"] = "1v2"
	(state["fighters"] as Array).pop_back()
	var result: Dictionary = loop.start(state)
	_assert_eq(result.get("status"), "rejected", "2v2 loop must reject other formats")
	_assert_eq(result.get("reason"), "unsupported_format", "format rejection must be explicit")


func _state(
	a1_pv: int,
	a2_pv: int,
	b1_pv: int,
	b2_pv: int,
	a1_power: int,
	a2_power: int,
	b1_power: int,
	b2_power: int
) -> Dictionary:
	return {
		"format": "2v2",
		"fighters":
		[
			_fighter("a1", "alpha", a1_pv, a1_power),
			_fighter("a2", "alpha", a2_pv, a2_power),
			_fighter("b1", "beta", b1_pv, b1_power),
			_fighter("b2", "beta", b2_pv, b2_power),
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
