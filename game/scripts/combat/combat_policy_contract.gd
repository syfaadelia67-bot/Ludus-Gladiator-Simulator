extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")

var _combat_contract = CombatContractScript.new()


func validate_desired_action(state: Dictionary, desired_action: Dictionary) -> Array[String]:
	var errors: Array[String] = _combat_contract.validate_state(state)
	if not errors.is_empty():
		return errors

	var actor_id := str(desired_action.get("actor_id", ""))
	var action_id := str(desired_action.get("action_id", ""))
	var target_id := str(desired_action.get("target_id", ""))

	if actor_id.is_empty():
		errors.append("Desired action is missing actor_id")
	elif not _fighter_exists(state, actor_id):
		errors.append("Desired action references unknown actor: %s" % actor_id)

	if action_id.is_empty():
		errors.append("Desired action is missing action_id")
	elif not _combat_contract.is_action_id_valid(action_id):
		errors.append("Desired action uses unsupported action: %s" % action_id)

	if not target_id.is_empty() and not _fighter_exists(state, target_id):
		errors.append("Desired action references unknown target: %s" % target_id)
	return errors


func is_valid_desired_action(state: Dictionary, desired_action: Dictionary) -> bool:
	return validate_desired_action(state, desired_action).is_empty()


func _fighter_exists(state: Dictionary, fighter_id: String) -> bool:
	var fighters_value: Variant = state.get("fighters", [])
	if not fighters_value is Array:
		return false
	for raw_fighter in fighters_value as Array:
		if (
			raw_fighter is Dictionary
			and str((raw_fighter as Dictionary).get("id", "")) == fighter_id
		):
			return true
	return false
