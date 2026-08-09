extends SceneTree

const CombatResolutionOrderBoundaryScript = preload(
	"res://scripts/combat/combat_resolution_order_boundary.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	var boundary = CombatResolutionOrderBoundaryScript.new()
	_test_valid_intents_remain_pending(boundary)
	_test_invalid_state_is_rejected(boundary)
	_test_invalid_intent_is_rejected(boundary)
	_test_non_dictionary_intent_is_rejected(boundary)
	_test_inputs_are_isolated(boundary)

	if _failures.is_empty():
		print("Combat resolution order boundary: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_valid_intents_remain_pending(boundary) -> void:
	var state := _state()
	var intents := [
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
		{"actor_id": "b", "action_id": "dodge"},
	]
	var result: Dictionary = boundary.inspect_intents(state, intents)
	_assert_eq(
		result.get("status"),
		"pending_design_freeze",
		"valid intents must stop at D3 design boundary",
	)
	_assert_eq(result.get("pending"), true, "D3 boundary must stay explicitly pending")
	_assert_eq(
		result.get("reason"),
		"resolution_order_not_frozen",
		"D3 boundary must expose stable pending reason",
	)
	_assert_eq(
		result.get("submitted_intents"),
		intents,
		"D3 boundary may preserve submissions but must not produce an order",
	)
	_assert_true(
		not result.has("ordered_intents"),
		"D3 boundary must not invent ordered intents before freeze",
	)
	_assert_true(
		not result.has("initiative"), "D3 boundary must not invent initiative before freeze"
	)


func _test_invalid_state_is_rejected(boundary) -> void:
	var state := _state()
	state["format"] = "3v3"
	var result: Dictionary = boundary.inspect_intents(
		state, [{"actor_id": "a", "action_id": "light", "target_id": "b"}]
	)
	_assert_eq(result.get("status"), "invalid_state", "invalid CombatState must fail closed")
	_assert_eq(result.get("pending"), false, "invalid state is not a pending D3 decision")


func _test_invalid_intent_is_rejected(boundary) -> void:
	var result: Dictionary = boundary.inspect_intents(
		_state(), [{"actor_id": "a", "action_id": "block", "target_id": "b"}]
	)
	_assert_eq(
		result.get("status"), "invalid_intents", "D3 boundary must reuse frozen D1 validation"
	)
	_assert_true(
		_contains_error(result.get("errors", []), "does not accept an explicit target"),
		"invalid D1 target must be surfaced before D3 ordering",
	)


func _test_non_dictionary_intent_is_rejected(boundary) -> void:
	var result: Dictionary = boundary.inspect_intents(_state(), ["not-an-intent"])
	_assert_eq(result.get("status"), "invalid_intents", "non-Dictionary intent must fail closed")
	_assert_true(
		_contains_error(result.get("errors", []), "must be a Dictionary"),
		"D3 boundary must explain invalid intent shape",
	)


func _test_inputs_are_isolated(boundary) -> void:
	var state := _state()
	var intents := [{"actor_id": "a", "action_id": "heavy", "target_id": "b"}]
	var state_before := state.duplicate(true)
	var intents_before := intents.duplicate(true)
	var result: Dictionary = boundary.inspect_intents(state, intents)
	_assert_eq(state, state_before, "D3 inspection must not mutate CombatState")
	_assert_eq(intents, intents_before, "D3 inspection must not mutate submitted intents")
	(result.get("state", {}) as Dictionary)["format"] = "2v2"
	(result.get("submitted_intents", []) as Array).clear()
	_assert_eq(state, state_before, "returned state copy must be isolated")
	_assert_eq(intents, intents_before, "returned intent copy must be isolated")


func _state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter("a", "alpha"),
			_fighter("b", "beta"),
		],
	}


func _fighter(id: String, team: String) -> Dictionary:
	return {
		"id": id,
		"team": team,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"stamina": 100,
	}


func _contains_error(errors_value: Variant, fragment: String) -> bool:
	if errors_value is not Array:
		return false
	for error_message in errors_value as Array:
		if str(error_message).contains(fragment):
			return true
	return false


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
