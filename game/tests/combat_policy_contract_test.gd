extends Node

const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")


func _ready() -> void:
	var policy = CombatPolicyContractScript.new()
	_assert_valid_intent(policy)
	_assert_unknown_actor_is_rejected(policy)
	_assert_unknown_action_is_rejected(policy)
	_assert_unknown_optional_target_is_rejected(policy)
	_assert_invalid_state_blocks_policy(policy)
	_assert_inputs_are_not_mutated(policy)
	print("Combat policy desired-action contract: OK")
	get_tree().quit(0)


func _assert_valid_intent(policy) -> void:
	var state := _state()
	var desired := {"actor_id": "a1", "action_id": "light", "target_id": "b1"}
	var errors: Array[String] = policy.validate_desired_action(state, desired)
	assert(errors.is_empty(), "Known actor/action/target intent must validate: %s" % [errors])
	assert(policy.is_valid_desired_action(state, desired))


func _assert_unknown_actor_is_rejected(policy) -> void:
	var errors: Array[String] = policy.validate_desired_action(
		_state(), {"actor_id": "missing", "action_id": "block"}
	)
	assert(_contains_error(errors, "unknown actor"))


func _assert_unknown_action_is_rejected(policy) -> void:
	var errors: Array[String] = policy.validate_desired_action(
		_state(), {"actor_id": "a1", "action_id": "god_mode"}
	)
	assert(_contains_error(errors, "unsupported action"))


func _assert_unknown_optional_target_is_rejected(policy) -> void:
	var errors: Array[String] = policy.validate_desired_action(
		_state(), {"actor_id": "a1", "action_id": "heavy", "target_id": "missing"}
	)
	assert(_contains_error(errors, "unknown target"))


func _assert_invalid_state_blocks_policy(policy) -> void:
	var state := _state()
	var first_fighter := (state["fighters"] as Array)[0] as Dictionary
	(first_fighter["stats"] as Dictionary)["RES"] = null
	var errors: Array[String] = policy.validate_desired_action(
		state, {"actor_id": "a1", "action_id": "light", "target_id": "b1"}
	)
	assert(
		_contains_error(errors, "unresolved stat RES"),
		"CombatPolicy must not validate intent over an invalid CombatState"
	)


func _assert_inputs_are_not_mutated(policy) -> void:
	var state := _state()
	var desired := {"actor_id": "a1", "action_id": "dodge"}
	var state_before := state.duplicate(true)
	var desired_before := desired.duplicate(true)
	policy.validate_desired_action(state, desired)
	assert(state == state_before, "Policy validation must not mutate CombatState")
	assert(desired == desired_before, "Policy validation must not mutate desired action")


func _state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters": [
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


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error_message in errors:
		if error_message.contains(fragment):
			return true
	return false
