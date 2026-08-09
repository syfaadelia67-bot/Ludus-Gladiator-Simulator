extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")

const PENDING_REASON := "resolution_order_not_frozen"

var _combat_contract = CombatContractScript.new()
var _policy_contract = CombatPolicyContractScript.new()


func inspect_intents(state: Dictionary, intents: Array) -> Dictionary:
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected("invalid_state", state_errors, state, intents)

	var intent_errors: Array[String] = []
	for index in range(intents.size()):
		var raw_intent: Variant = intents[index]
		if raw_intent is not Dictionary:
			intent_errors.append("Resolution-order intent %d must be a Dictionary" % index)
			continue
		var errors: Array[String] = _policy_contract.validate_desired_action(
			state, raw_intent as Dictionary
		)
		for error_message in errors:
			intent_errors.append("Intent %d: %s" % [index, error_message])

	if not intent_errors.is_empty():
		return _rejected("invalid_intents", intent_errors, state, intents)

	return {
		"status": "pending_design_freeze",
		"pending": true,
		"reason": PENDING_REASON,
		"errors": [],
		"state": state.duplicate(true),
		"submitted_intents": intents.duplicate(true),
	}


func _rejected(
	status: String, errors: Array[String], state: Dictionary, intents: Array
) -> Dictionary:
	return {
		"status": status,
		"pending": false,
		"reason": "",
		"errors": errors.duplicate(),
		"state": state.duplicate(true),
		"submitted_intents": intents.duplicate(true),
	}
