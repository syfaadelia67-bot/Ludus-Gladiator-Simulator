extends RefCounted

const ACTION_COSTS := {
	"light": 3,
	"heavy": 5,
	"block": 2,
	"parry": 3,
	"dodge": 4,
	"reposition": 2,
}
const RECOVERY_AMOUNT := 2
const RECOVERY_TIMING := "end_exchange"


func can_pay(fighter: Dictionary, action_id: String) -> bool:
	if not ACTION_COSTS.has(action_id):
		return false
	if not fighter.has("stamina") or not _is_numeric(fighter["stamina"]):
		return false
	return float(fighter["stamina"]) >= float(ACTION_COSTS[action_id])


func spend(fighter: Dictionary, action_id: String) -> Dictionary:
	if not ACTION_COSTS.has(action_id):
		return _invalid("unsupported_stamina_action", fighter)
	if not fighter.has("stamina") or not _is_numeric(fighter["stamina"]):
		return _invalid("invalid_stamina", fighter)
	var current := float(fighter["stamina"])
	var cost := float(ACTION_COSTS[action_id])
	if current < cost:
		return _invalid("insufficient_stamina", fighter)
	var updated := fighter.duplicate(true)
	updated["stamina"] = current - cost
	return {
		"status": "resolved",
		"errors": [],
		"action_id": action_id,
		"cost": int(cost),
		"fighter": updated,
	}


func recover(fighter: Dictionary) -> Dictionary:
	if not fighter.has("stamina") or not _is_numeric(fighter["stamina"]):
		return _invalid("invalid_stamina", fighter)
	var current := float(fighter["stamina"])
	var capacity := current
	if fighter.has("stamina_capacity"):
		if not _is_numeric(fighter["stamina_capacity"]):
			return _invalid("invalid_stamina_capacity", fighter)
		capacity = float(fighter["stamina_capacity"])
	if capacity < 0.0 or current < 0.0 or current > capacity:
		return _invalid("invalid_stamina_bounds", fighter)
	var updated := fighter.duplicate(true)
	updated["stamina"] = min(capacity, current + float(RECOVERY_AMOUNT))
	return {
		"status": "resolved",
		"errors": [],
		"recovery": RECOVERY_AMOUNT,
		"timing": RECOVERY_TIMING,
		"fighter": updated,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"action_costs": ACTION_COSTS.duplicate(true),
		"recovery_amount": RECOVERY_AMOUNT,
		"recovery_timing": RECOVERY_TIMING,
		"insufficient_stamina_behavior": "reject_action",
		"recovery_cap_field": "stamina_capacity",
	}


func _invalid(error: String, fighter: Dictionary) -> Dictionary:
	return {
		"status": "invalid",
		"errors": [error],
		"fighter": fighter.duplicate(true),
	}


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float
