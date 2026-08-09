extends Node

const CombatSimulatorScript = preload("res://scripts/combat/combat_simulator.gd")


func _ready() -> void:
	var simulator = CombatSimulatorScript.new()
	_assert_valid_intent_stays_pending(simulator)
	_assert_invalid_target_intent_is_rejected(simulator)
	_assert_invalid_state_is_rejected(simulator)
	_assert_invalid_intent_is_rejected(simulator)
	_assert_inputs_are_not_mutated(simulator)
	print("Combat Simulator authority boundary: OK")
	get_tree().quit(0)


func _assert_valid_intent_stays_pending(simulator) -> void:
	var result: Dictionary = simulator.resolve_intent(
		_state(), {"actor_id": "a1", "action_id": "light", "target_id": "b1"}
	)
	assert(not bool(result.get("ok", true)), "Unfrozen combat math must not return a fake success")
	assert(bool(result.get("pending", false)), "A valid intent must remain explicitly pending")
	assert(
		str(result.get("reason", "")) == simulator.PENDING_REASON,
		"Pending resolution must expose the frozen reason code"
	)
	assert((result.get("errors", []) as Array).is_empty())
	assert(
		str(result.get("blocking_requirement", "")) == "resolution_order",
		"D3 resolution order must become the first required blocker after D1 freeze",
	)
	var blocking_context := result.get("blocking_context", {}) as Dictionary
	var target_context := blocking_context.get("resolved_target_context", {}) as Dictionary
	assert(target_context.get("status") == "ready", "D1 target context must be fully resolved")
	assert(target_context.get("legal_targets") == ["b1"], "resolved D1 context must expose enemy target")
	assert(target_context.get("target_relationship") == "enemy")
	var pending_requirements := result.get("pending_requirements", []) as Array
	assert(not pending_requirements.has("target_rules"), "Frozen D1 must leave pending readiness")
	assert(pending_requirements.has("resolution_order"), "D3 must remain explicitly pending")
	assert(
		pending_requirements.has("damage_and_mitigation"),
		"Damage and mitigation must remain explicitly pending"
	)
	assert(
		pending_requirements.has("stamina_costs"), "Stamina costs must remain explicitly pending"
	)
	var conditional_requirements := result.get("conditional_requirements", []) as Array
	assert(
		conditional_requirements.has("position_and_distance_model"),
		"Position/distance must remain conditional until design freezes D2"
	)
	(target_context.get("legal_targets", []) as Array).clear()
	var nested_target_context := (
		(result.get("blocking_context", {}) as Dictionary).get("resolved_target_context", {}) as Dictionary
	)
	assert(
		(nested_target_context.get("legal_targets", []) as Array).is_empty(),
		"caller may mutate its returned target context copy",
	)


func _assert_invalid_target_intent_is_rejected(simulator) -> void:
	var result: Dictionary = simulator.resolve_intent(
		_state(), {"actor_id": "a1", "action_id": "block", "target_id": "b1"}
	)
	assert(not bool(result.get("pending", true)))
	assert(str(result.get("reason", "")) == "invalid_desired_action")
	assert(_contains_error(result.get("errors", []), "does not accept an explicit target"))
	assert(str(result.get("blocking_requirement", "")).is_empty())


func _assert_invalid_state_is_rejected(simulator) -> void:
	var state := _state()
	var first_fighter := (state["fighters"] as Array)[0] as Dictionary
	(first_fighter["stats"] as Dictionary)["RES"] = null
	var result: Dictionary = simulator.resolve_intent(
		state, {"actor_id": "a1", "action_id": "light", "target_id": "b1"}
	)
	assert(not bool(result.get("pending", true)))
	assert(str(result.get("reason", "")) == "invalid_state")
	assert(_contains_error(result.get("errors", []), "unresolved stat RES"))
	assert((result.get("pending_requirements", []) as Array).is_empty())
	assert(str(result.get("blocking_requirement", "")).is_empty())
	assert((result.get("blocking_context", {}) as Dictionary).is_empty())


func _assert_invalid_intent_is_rejected(simulator) -> void:
	var result: Dictionary = simulator.resolve_intent(
		_state(), {"actor_id": "a1", "action_id": "unsupported"}
	)
	assert(not bool(result.get("pending", true)))
	assert(str(result.get("reason", "")) == "invalid_desired_action")
	assert(_contains_error(result.get("errors", []), "unsupported action"))
	assert((result.get("pending_requirements", []) as Array).is_empty())
	assert(str(result.get("blocking_requirement", "")).is_empty())
	assert((result.get("blocking_context", {}) as Dictionary).is_empty())


func _assert_inputs_are_not_mutated(simulator) -> void:
	var state := _state()
	var desired := {"actor_id": "a1", "action_id": "dodge"}
	var state_before := state.duplicate(true)
	var desired_before := desired.duplicate(true)
	simulator.resolve_intent(state, desired)
	assert(state == state_before, "CombatSimulator boundary must not mutate CombatState")
	assert(desired == desired_before, "CombatSimulator boundary must not mutate desired action")


func _state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter("a1", "a"),
			_fighter("b1", "b"),
		],
	}


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 10},
		"stamina": 10,
	}


func _contains_error(errors_value: Variant, fragment: String) -> bool:
	if not errors_value is Array:
		return false
	for raw_error in errors_value as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
