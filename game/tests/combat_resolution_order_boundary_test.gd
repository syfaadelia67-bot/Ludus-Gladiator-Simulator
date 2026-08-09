extends SceneTree

const CombatResolutionOrderBoundaryScript = preload(
	"res://scripts/combat/combat_resolution_order_boundary.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	var boundary = CombatResolutionOrderBoundaryScript.new()
	_test_1v1_phase_plan(boundary)
	_test_1v2_requires_complete_exchange(boundary)
	_test_2v2_phase_plan_is_input_order_independent(boundary)
	_test_duplicate_actor_is_rejected(boundary)
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


func _test_1v1_phase_plan(boundary) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	var intents := [
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
		{"actor_id": "b", "action_id": "dodge"},
	]
	var result: Dictionary = boundary.build_resolution_plan(state, intents)
	_assert_eq(result.get("status"), "ready", "frozen D3 must produce a resolution plan")
	_assert_eq(result.get("pending"), false, "frozen D3 must not remain pending")
	_assert_eq(result.get("phase_order"), ["preparation", "offense"], "D3 phase order is fixed")
	_assert_eq(result.get("initiative_mode"), "none", "D3 must not invent initiative")
	_assert_eq(result.get("tie_break_mode"), "simultaneous", "same-phase intents are simultaneous")
	var phases := result.get("phases", []) as Array
	_assert_eq(phases.size(), 2, "D3 must expose exactly two phases")
	var preparation := phases[0] as Dictionary
	var offense := phases[1] as Dictionary
	_assert_eq(preparation.get("id"), "preparation", "defensive/tactical phase resolves first")
	_assert_eq(preparation.get("snapshot"), "exchange_start", "preparation shares exchange-start snapshot")
	_assert_eq(preparation.get("simultaneous"), true, "preparation intents are simultaneous")
	_assert_eq((preparation.get("intents", []) as Array).size(), 1, "dodge belongs to preparation")
	_assert_eq(offense.get("id"), "offense", "offense resolves second")
	_assert_eq(offense.get("snapshot"), "after_preparation_commit", "offense sees committed preparation")
	_assert_eq(offense.get("simultaneous"), true, "offensive intents are simultaneous")
	_assert_eq((offense.get("intents", []) as Array).size(), 1, "light belongs to offense")


func _test_1v2_requires_complete_exchange(boundary) -> void:
	var state := _state(
		"1v2",
		[_fighter("a", "alpha"), _fighter("b", "beta"), _fighter("b2", "beta")],
	)
	var incomplete := [
		{"actor_id": "a", "action_id": "heavy", "target_id": "b"},
		{"actor_id": "b", "action_id": "block"},
	]
	var rejected: Dictionary = boundary.build_resolution_plan(state, incomplete)
	_assert_eq(rejected.get("status"), "invalid_intents", "1v2 needs one intent from all three fighters")
	_assert_true(
		_contains_error(rejected.get("errors", []), "Fighter b2 must submit exactly one intent"),
		"missing 1v2 actor must be named",
	)
	var complete := incomplete.duplicate(true)
	complete.append({"actor_id": "b2", "action_id": "light", "target_id": "a"})
	_assert_eq(
		boundary.build_resolution_plan(state, complete).get("status"),
		"ready",
		"complete 1v2 exchange must be accepted",
	)


func _test_2v2_phase_plan_is_input_order_independent(boundary) -> void:
	var state := _state(
		"2v2",
		[
			_fighter("a", "alpha"),
			_fighter("a2", "alpha"),
			_fighter("b", "beta"),
			_fighter("b2", "beta"),
		],
	)
	var intents := [
		{"actor_id": "b2", "action_id": "heavy", "target_id": "a2"},
		{"actor_id": "a2", "action_id": "parry"},
		{"actor_id": "b", "action_id": "reposition"},
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
	]
	var result: Dictionary = boundary.build_resolution_plan(state, intents)
	_assert_eq(result.get("status"), "ready", "2v2 exchange must resolve into phases")
	var phases := result.get("phases", []) as Array
	var preparation := phases[0] as Dictionary
	var offense := phases[1] as Dictionary
	_assert_eq(
		_actor_ids(preparation.get("intents", [])),
		["a2", "b"],
		"preparation serialization is canonical but not priority",
	)
	_assert_eq(
		_actor_ids(offense.get("intents", [])),
		["a", "b2"],
		"offense serialization is canonical but same-phase semantics remain simultaneous",
	)


func _test_duplicate_actor_is_rejected(boundary) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	var intents := [
		{"actor_id": "a", "action_id": "block"},
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
	]
	var result: Dictionary = boundary.build_resolution_plan(state, intents)
	_assert_eq(result.get("status"), "invalid_intents", "one actor cannot submit twice")
	_assert_true(
		_contains_error(result.get("errors", []), "submitted more than one intent"),
		"duplicate actor rejection must be explicit",
	)


func _test_invalid_state_is_rejected(boundary) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	state["format"] = "3v3"
	var result: Dictionary = boundary.build_resolution_plan(
		state,
		[
			{"actor_id": "a", "action_id": "light", "target_id": "b"},
			{"actor_id": "b", "action_id": "dodge"},
		],
	)
	_assert_eq(result.get("status"), "invalid_state", "invalid CombatState must fail closed")


func _test_invalid_intent_is_rejected(boundary) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	var result: Dictionary = boundary.build_resolution_plan(
		state,
		[
			{"actor_id": "a", "action_id": "block", "target_id": "b"},
			{"actor_id": "b", "action_id": "dodge"},
		],
	)
	_assert_eq(result.get("status"), "invalid_intents", "D3 must reuse frozen D1 validation")
	_assert_true(
		_contains_error(result.get("errors", []), "does not accept an explicit target"),
		"invalid D1 target must be surfaced before phase planning",
	)


func _test_non_dictionary_intent_is_rejected(boundary) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	var result: Dictionary = boundary.build_resolution_plan(state, ["not-an-intent"])
	_assert_eq(result.get("status"), "invalid_intents", "non-Dictionary intent must fail closed")
	_assert_true(
		_contains_error(result.get("errors", []), "must be a Dictionary"),
		"D3 must explain invalid intent shape",
	)


func _test_inputs_are_isolated(boundary) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	var intents := [
		{"actor_id": "a", "action_id": "heavy", "target_id": "b"},
		{"actor_id": "b", "action_id": "block"},
	]
	var state_before := state.duplicate(true)
	var intents_before := intents.duplicate(true)
	var result: Dictionary = boundary.build_resolution_plan(state, intents)
	_assert_eq(state, state_before, "D3 planning must not mutate CombatState")
	_assert_eq(intents, intents_before, "D3 planning must not mutate submitted intents")
	(result.get("state", {}) as Dictionary)["format"] = "2v2"
	(result.get("submitted_intents", []) as Array).clear()
	var phases := result.get("phases", []) as Array
	((phases[1] as Dictionary).get("intents", []) as Array).clear()
	_assert_eq(state, state_before, "returned state copy must be isolated")
	_assert_eq(intents, intents_before, "returned plan copies must be isolated")


func _state(format_id: String, fighters: Array) -> Dictionary:
	return {"format": format_id, "fighters": fighters}


func _fighter(id: String, team: String) -> Dictionary:
	return {
		"id": id,
		"team": team,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"stamina": 100,
	}


func _actor_ids(intents_value: Variant) -> Array[String]:
	var ids: Array[String] = []
	if intents_value is not Array:
		return ids
	for raw_intent in intents_value as Array:
		ids.append(str((raw_intent as Dictionary).get("actor_id", "")))
	return ids


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
