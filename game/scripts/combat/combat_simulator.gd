extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")

const PENDING_REASON := "combat_resolution_rules_not_frozen"

var _combat_contract = CombatContractScript.new()
var _policy_contract = CombatPolicyContractScript.new()


func resolve_intent(state: Dictionary, desired_action: Dictionary) -> Dictionary:
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected_result("invalid_state", state_errors, state, desired_action)

	var policy_errors: Array[String] = _policy_contract.validate_desired_action(state, desired_action)
	if not policy_errors.is_empty():
		return _rejected_result("invalid_desired_action", policy_errors, state, desired_action)

	return {
		"ok": false,
		"pending": true,
		"reason": PENDING_REASON,
		"errors": [],
		"state": state.duplicate(true),
		"desired_action": desired_action.duplicate(true),
	}


func _rejected_result(
	reason: String,
	errors: Array[String],
	state: Dictionary,
	desired_action: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"pending": false,
		"reason": reason,
		"errors": errors.duplicate(),
		"state": state.duplicate(true),
		"desired_action": desired_action.duplicate(true),
	}
