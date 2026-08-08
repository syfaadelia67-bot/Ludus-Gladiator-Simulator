extends SceneTree

const CombatTargetResolverScript = preload("res://scripts/combat/combat_target_resolver.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var resolver = CombatTargetResolverScript.new()
	_test_1v1_candidates(resolver)
	_test_2v2_candidates(resolver)
	_test_1v2_candidates(resolver)
	_test_action_target_rules_stay_pending(resolver)
	_test_invalid_inputs_fail_closed(resolver)
	_test_results_are_isolated(resolver)

	if _failures.is_empty():
		print("Combat target resolver contract: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_1v1_candidates(resolver) -> void:
	var result: Dictionary = resolver.get_candidate_groups(
		_state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")]), "a"
	)
	_assert_eq(result.get("status"), "ready", "1v1 candidate inspection must succeed")
	var candidates := result.get("candidates", {}) as Dictionary
	_assert_eq(candidates.get("allies"), [], "1v1 actor has no ally candidates")
	_assert_eq(candidates.get("enemies"), ["b"], "1v1 actor sees opposing candidate")
	_assert_true(not result.has("legal_targets"), "candidate boundary must not invent legal targets")


func _test_2v2_candidates(resolver) -> void:
	var state := _state(
		"2v2",
		[
			_fighter("a", "alpha"),
			_fighter("a2", "alpha"),
			_fighter("b", "beta"),
			_fighter("b2", "beta"),
		],
	)
	var candidates := resolver.get_candidate_groups(state, "a").get("candidates", {}) as Dictionary
	_assert_eq(candidates.get("allies"), ["a2"], "2v2 actor sees ally candidate")
	_assert_eq(candidates.get("enemies"), ["b", "b2"], "2v2 actor sees enemy candidates")


func _test_1v2_candidates(resolver) -> void:
	var state := _state(
		"1v2",
		[
			_fighter("a", "alpha"),
			_fighter("b", "beta"),
			_fighter("b2", "beta"),
		],
	)
	var larger_team := resolver.get_candidate_groups(state, "b").get("candidates", {}) as Dictionary
	_assert_eq(larger_team.get("allies"), ["b2"], "1v2 larger side sees teammate")
	_assert_eq(larger_team.get("enemies"), ["a"], "1v2 larger side sees solo opponent")
	var solo_side := resolver.get_candidate_groups(state, "a").get("candidates", {}) as Dictionary
	_assert_eq(solo_side.get("allies"), [], "1v2 solo side has no ally candidate")
	_assert_eq(solo_side.get("enemies"), ["b", "b2"], "1v2 solo side sees both opponents")


func _test_action_target_rules_stay_pending(resolver) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	for action_id in ["light", "heavy", "block", "parry", "dodge", "reposition"]:
		var result: Dictionary = resolver.inspect_action_targets(state, "a", action_id)
		_assert_eq(
			result.get("status"),
			"pending_design_freeze",
			"%s target semantics must remain pending" % action_id,
		)
		_assert_eq(result.get("pending"), true, "%s target resolution must be pending" % action_id)
		_assert_eq(
			result.get("reason"),
			"target_rules_not_frozen",
			"%s must expose D1 pending reason" % action_id,
		)
		_assert_true(not result.has("legal_targets"), "%s must not expose legal targets yet" % action_id)


func _test_invalid_inputs_fail_closed(resolver) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	_assert_eq(
		resolver.get_candidate_groups(state, "missing").get("status"),
		"invalid_actor",
		"unknown actor must fail closed",
	)
	_assert_eq(
		resolver.inspect_action_targets(state, "a", "invented").get("status"),
		"invalid_action",
		"unknown action must fail closed",
	)
	var invalid_state := state.duplicate(true)
	invalid_state["format"] = "3v3"
	_assert_eq(
		resolver.get_candidate_groups(invalid_state, "a").get("status"),
		"invalid_state",
		"invalid CombatState must fail before target inspection",
	)


func _test_results_are_isolated(resolver) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	var state_before := state.duplicate(true)
	var result: Dictionary = resolver.inspect_action_targets(state, "a", "light")
	var candidates := result.get("candidates", {}) as Dictionary
	var enemies := candidates.get("enemies", []) as Array
	enemies.clear()
	_assert_eq(state, state_before, "target inspection must never mutate CombatState")
	var rebuilt: Dictionary = resolver.inspect_action_targets(state, "a", "light")
	_assert_eq(
		((rebuilt.get("candidates", {}) as Dictionary).get("enemies", [])),
		["b"],
		"mutating returned candidates must not affect later inspections",
	)


func _state(format_id: String, fighters: Array) -> Dictionary:
	return {"format": format_id, "fighters": fighters}


func _fighter(id: String, team: String) -> Dictionary:
	return {
		"id": id,
		"team": team,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"stamina": 100,
	}


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
