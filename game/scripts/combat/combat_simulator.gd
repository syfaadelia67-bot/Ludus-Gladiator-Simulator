extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")
const CombatResolutionReadinessScript = preload(
	"res://scripts/combat/combat_resolution_readiness.gd"
)

const PENDING_REASON := "combat_resolution_rules_not_frozen"

var _combat_contract = CombatContractScript.new()
var _policy_contract = CombatPolicyContractScript.new()
var _resolution_readiness = CombatResolutionReadinessScript.new()


func resolve_intent(state: Dictionary, desired_action: Dictionary) -> Dictionary:
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected_result("invalid_state", state_errors, state, desired_action)

	var policy_errors: Array[String] = _policy_contract.validate_desired_action(
		state, desired_action
	)
	if not policy_errors.is_empty():
		return _rejected_result("invalid_desired_action", policy_errors, state, desired_action)

	return {
		"ok": false,
		"pending": true,
		"reason": PENDING_REASON,
		"errors": [],
		"pending_requirements": _resolution_readiness.get_pending_requirements(),
		"conditional_requirements": _resolution_readiness.get_conditional_requirements(),
		"state": state.duplicate(true),
		"desired_action": desired_action.duplicate(true),
	}


func _rejected_result(
	reason: String, errors: Array[String], state: Dictionary, desired_action: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"pending": false,
		"reason": reason,
		"errors": errors.duplicate(),
		"pending_requirements": [],
		"conditional_requirements": [],
		"state": state.duplicate(true),
		"desired_action": desired_action.duplicate(true),
	}
