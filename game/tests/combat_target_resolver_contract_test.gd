extends SceneTree

const CombatTargetResolverScript = preload("res://scripts/combat/combat_target_resolver.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var resolver = CombatTargetResolverScript.new()
	_test_1v1_candidates(resolver)
	_test_2v2_candidates(resolver)
	_test_1v2_candidates(resolver)
	_test_frozen_action_target_rules(resolver)
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
	var light := resolver.inspect_action_targets(state, "a", "light")
	_assert_eq(light.get("legal_targets"), ["b", "b2"], "2v2 light may target either enemy")


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
	_assert_eq(
		resolver.inspect_action_targets(state, "a", "heavy").get("legal_targets"),
		["b", "b2"],
		"1v2 solo side may heavy either enemy",
	)


func _test_frozen_action_target_rules(resolver) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	for action_id in ["light", "heavy"]:
		var result: Dictionary = resolver.inspect_action_targets(state, "a", action_id)
		_assert_eq(result.get("status"), "ready", "%s target semantics must be frozen" % action_id)
		_assert_eq(result.get("pending"), false, "%s target resolution must be ready" % action_id)
		_assert_eq(result.get("target_required"), true, "%s requires explicit target" % action_id)
		_assert_eq(result.get("target_relationship"), "enemy", "%s targets enemies" % action_id)
		_assert_eq(result.get("target_count"), 1, "%s targets exactly one enemy" % action_id)
		_assert_eq(result.get("legal_targets"), ["b"], "%s exposes opponent as legal" % action_id)
	for action_id in ["block", "parry", "dodge", "reposition"]:
		var result: Dictionary = resolver.inspect_action_targets(state, "a", action_id)
		_assert_eq(result.get("status"), "ready", "%s target semantics must be frozen" % action_id)
		_assert_eq(result.get("target_required"), false, "%s has no explicit target" % action_id)
		_assert_eq(
			result.get("target_relationship"), "none", "%s target relationship is none" % action_id
		)
		_assert_eq(result.get("target_count"), 0, "%s accepts zero explicit targets" % action_id)
		_assert_eq(result.get("legal_targets"), [], "%s has no legal explicit targets" % action_id)


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
	var legal_targets := result.get("legal_targets", []) as Array
	legal_targets.clear()
	_assert_eq(state, state_before, "target inspection must never mutate CombatState")
	var rebuilt: Dictionary = resolver.inspect_action_targets(state, "a", "light")
	_assert_eq(rebuilt.get("legal_targets", []), ["b"], "returned legal targets must be isolated")


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
