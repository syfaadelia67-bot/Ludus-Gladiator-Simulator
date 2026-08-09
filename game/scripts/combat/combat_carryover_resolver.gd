extends RefCounted

const RuntimeStateBuilderScript = preload("res://scripts/combat/combat_runtime_state_builder.gd")

var _runtime_builder = RuntimeStateBuilderScript.new()


func prepare_consecutive_fight(previous_state: Dictionary, next_state: Dictionary) -> Dictionary:
	var previous_errors: Array[String] = _runtime_builder.validate_runtime_state(previous_state)
	if not previous_errors.is_empty():
		return _invalid("invalid_previous_runtime_state", previous_errors, next_state)

	var next_runtime_result: Dictionary = _runtime_builder.build(next_state)
	if next_runtime_result.get("status") != "ready":
		return _invalid(
			"invalid_next_combat_state",
			next_runtime_result.get("errors", []) as Array,
			next_state,
		)

	var carried_state := (next_runtime_result.get("state", {}) as Dictionary).duplicate(true)
	var previous_by_id: Dictionary = _fighters_by_id(previous_state)
	var carried_fighter_ids: Array[String] = []
	var fighters := carried_state.get("fighters", []) as Array
	for index in range(fighters.size()):
		var fighter := fighters[index] as Dictionary
		var fighter_id := str(fighter.get("id", ""))
		if not previous_by_id.has(fighter_id):
			continue
		var previous_fighter := previous_by_id[fighter_id] as Dictionary
		var max_pv := float((fighter.get("stats", {}) as Dictionary).get("PV", 0.0))
		var stamina_capacity := float(fighter.get("stamina_capacity", fighter.get("stamina", 0.0)))
		fighter["current_pv"] = clampf(float(previous_fighter.get("current_pv", max_pv)), 0.0, max_pv)
		fighter["stamina"] = clampf(
			float(previous_fighter.get("stamina", stamina_capacity)), 0.0, stamina_capacity
		)
		fighter["vulnerable"] = false
		fighters[index] = fighter
		carried_fighter_ids.append(fighter_id)

	return {
		"status": "ready",
		"errors": [],
		"state": carried_state.duplicate(true),
		"carried_fighter_ids": carried_fighter_ids.duplicate(),
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"within_same_combat": ["current_pv", "stamina", "vulnerable"],
		"between_consecutive_gt_fights": ["current_pv", "stamina"],
		"between_fight_reset": ["vulnerable", "submitted_intents", "exchange_state"],
		"fighter_identity_key": "id",
		"ko_carries_as_zero_pv": true,
		"full_heal_between_consecutive_fights": false,
		"full_stamina_restore_between_consecutive_fights": false,
	}


func _fighters_by_id(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		result[str(fighter.get("id", ""))] = fighter.duplicate(true)
	return result


func _invalid(reason: String, errors: Array, state: Dictionary) -> Dictionary:
	return {
		"status": "invalid",
		"reason": reason,
		"errors": errors.duplicate(),
		"state": state.duplicate(true),
		"carried_fighter_ids": [],
	}
