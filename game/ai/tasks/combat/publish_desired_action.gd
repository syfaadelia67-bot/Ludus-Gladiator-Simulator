@tool
extends BTAction

const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")

@export var combat_state_var: StringName = &"combat_state"
@export var proposal_var: StringName = &"policy_proposal"
@export var desired_action_var: StringName = &"desired_action"
@export var policy_errors_var: StringName = &"policy_errors"

var _policy_contract = CombatPolicyContractScript.new()


func _generate_name() -> String:
	return "Publish Valid Desired Action"


func _tick(_delta: float) -> Status:
	var state_value: Variant = blackboard.get_var(combat_state_var, {})
	var proposal_value: Variant = blackboard.get_var(proposal_var, {})
	if state_value is not Dictionary or proposal_value is not Dictionary:
		_reject(["Policy proposal requires Dictionary combat_state and policy_proposal"])
		return FAILURE

	var state := state_value as Dictionary
	var proposal := proposal_value as Dictionary
	var errors: Array[String] = _policy_contract.validate_desired_action(state, proposal)
	if not errors.is_empty():
		_reject(errors)
		return FAILURE

	blackboard.set_var(desired_action_var, proposal.duplicate(true))
	blackboard.set_var(policy_errors_var, [])
	return SUCCESS


func _reject(errors: Array[String]) -> void:
	blackboard.set_var(desired_action_var, {})
	blackboard.set_var(policy_errors_var, errors.duplicate())
