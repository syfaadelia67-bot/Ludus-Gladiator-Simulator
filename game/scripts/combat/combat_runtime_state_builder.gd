extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")

var _combat_contract = CombatContractScript.new()


func build(state: Dictionary) -> Dictionary:
	var errors: Array[String] = _combat_contract.validate_state(state)
	if not errors.is_empty():
		return {
			"status": "invalid_state",
			"errors": errors.duplicate(),
			"state": state.duplicate(true),
		}

	var runtime_state := state.duplicate(true)
	var fighters := runtime_state.get("fighters", []) as Array
	for raw_fighter in fighters:
		var fighter := raw_fighter as Dictionary
		var stats := fighter.get("stats", {}) as Dictionary
		fighter["current_pv"] = float(stats.get("PV", 0.0))
		fighter["vulnerable"] = false
		if not fighter.has("stamina_capacity"):
			fighter["stamina_capacity"] = float(fighter.get("stamina", 0.0))

	var runtime_errors := validate_runtime_state(runtime_state)
	if not runtime_errors.is_empty():
		return {
			"status": "invalid_runtime_state",
			"errors": runtime_errors,
			"state": runtime_state,
		}

	return {
		"status": "ready",
		"errors": [],
		"state": runtime_state,
	}


func validate_runtime_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = _combat_contract.validate_state(state)
	if not errors.is_empty():
		return errors

	var fighters := state.get("fighters", []) as Array
	for raw_fighter in fighters:
		var fighter := raw_fighter as Dictionary
		var fighter_id := str(fighter.get("id", ""))
		if not fighter.has("current_pv") or not _is_numeric(fighter["current_pv"]):
			errors.append("Combat fighter %s current_pv must be numeric" % fighter_id)
		elif float(fighter["current_pv"]) < 0.0:
			errors.append("Combat fighter %s current_pv cannot be negative" % fighter_id)
		if not fighter.has("vulnerable") or fighter["vulnerable"] is not bool:
			errors.append("Combat fighter %s vulnerable must be bool" % fighter_id)
		if not fighter.has("stamina_capacity") or not _is_numeric(fighter["stamina_capacity"]):
			errors.append("Combat fighter %s stamina_capacity must be numeric" % fighter_id)
		else:
			var capacity := float(fighter["stamina_capacity"])
			var stamina := float(fighter.get("stamina", 0.0))
			if capacity < 0.0:
				errors.append("Combat fighter %s stamina_capacity cannot be negative" % fighter_id)
			elif stamina > capacity:
				errors.append(
					"Combat fighter %s stamina cannot exceed stamina_capacity" % fighter_id
				)
	return errors


func is_knocked_out(fighter: Dictionary) -> bool:
	if not fighter.has("current_pv") or not _is_numeric(fighter["current_pv"]):
		return false
	return float(fighter["current_pv"]) <= 0.0


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float
