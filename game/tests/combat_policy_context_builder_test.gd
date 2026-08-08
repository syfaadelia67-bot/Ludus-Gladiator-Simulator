extends SceneTree

const CombatPolicyContextBuilderScript = preload("res://scripts/combat/combat_policy_context_builder.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var builder = CombatPolicyContextBuilderScript.new()
	_test_1v1_context(builder)
	_test_2v2_relationships(builder)
	_test_1v2_relationships(builder)
	_test_invalid_inputs(builder)

	if _failures.is_empty():
		print("Combat policy context builder: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_1v1_context(builder) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	var result: Dictionary = builder.build_context(state, "a")
	_assert_eq(result.get("status"), "ready", "1v1 context must build")
	var context := result.get("context", {}) as Dictionary
	_assert_eq(context.get("format"), "1v1", "context must expose combat format")
	_assert_eq((context.get("actor") as Dictionary).get("id"), "a", "context must expose actor")
	_assert_eq((context.get("allies") as Array).size(), 0, "1v1 actor has no allies")
	_assert_eq((context.get("enemies") as Array).size(), 1, "1v1 actor has one enemy")
	_assert_eq(
		context.get("available_action_ids"),
		["light", "heavy", "block", "parry", "dodge", "reposition"],
		"context must expose the canonical action catalog",
	)
	var candidates := context.get("target_candidates") as Dictionary
	_assert_eq(candidates.get("allies"), [], "1v1 ally candidates must be empty")
	_assert_eq(candidates.get("enemies"), ["b"], "1v1 enemy candidates must expose opponent")
	var isolated_actor := context.get("actor") as Dictionary
	isolated_actor["stamina"] = 0
	_assert_eq((state.get("fighters") as Array)[0].get("stamina"), 100, "actor view must be isolated")


func _test_2v2_relationships(builder) -> void:
	var state := _state(
		"2v2",
		[
			_fighter("a", "alpha"),
			_fighter("a2", "alpha"),
			_fighter("b", "beta"),
			_fighter("b2", "beta"),
		],
	)
	var context := (builder.build_context(state, "a").get("context", {}) as Dictionary)
	_assert_eq(_ids(context.get("allies") as Array), ["a2"], "2v2 must classify ally")
	_assert_eq(_ids(context.get("enemies") as Array), ["b", "b2"], "2v2 must classify enemies")


func _test_1v2_relationships(builder) -> void:
	var state := _state(
		"1v2",
		[
			_fighter("a", "alpha"),
			_fighter("b", "beta"),
			_fighter("b2", "beta"),
		],
	)
	var context := (builder.build_context(state, "b").get("context", {}) as Dictionary)
	_assert_eq(_ids(context.get("allies") as Array), ["b2"], "1v2 larger team must expose ally")
	_assert_eq(_ids(context.get("enemies") as Array), ["a"], "1v2 larger team must expose enemy")


func _test_invalid_inputs(builder) -> void:
	var valid_state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	_assert_eq(
		builder.build_context(valid_state, "missing").get("status"),
		"invalid_actor",
		"unknown actor must be rejected",
	)
	var invalid_state := valid_state.duplicate(true)
	invalid_state["format"] = "3v3"
	_assert_eq(
		builder.build_context(invalid_state, "a").get("status"),
		"invalid_state",
		"unsupported combat state must be rejected before policy perception",
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


func _ids(fighters: Array) -> Array[String]:
	var result: Array[String] = []
	for fighter in fighters:
		result.append(str((fighter as Dictionary).get("id", "")))
	return result


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
