extends RefCounted

const ACTION_COSTS := {
	"light": 3,
	"heavy": 5,
	"block": 2,
	"parry": 3,
	"dodge": 4,
	"reposition": 2,
	"recover": 0,
}
const RECOVERY_AMOUNT := 2
const RECOVERY_TIMING := "end_exchange"


func get_action_cost(action_id: String) -> int:
	return int(ACTION_COSTS.get(action_id, -1))


func can_pay(fighter: Dictionary, action_id: String) -> bool:
	return can_pay_cost(fighter, get_action_cost(action_id))


func can_pay_cost(fighter: Dictionary, cost: int) -> bool:
	if cost < 0:
		return false
	if not fighter.has("stamina") or not _is_numeric(fighter["stamina"]):
		return false
	return float(fighter["stamina"]) >= float(cost)


func spend(fighter: Dictionary, action_id: String) -> Dictionary:
	var cost := get_action_cost(action_id)
	if cost < 0:
		return _invalid("unsupported_stamina_action", fighter)
	return spend_cost(fighter, cost, action_id)


func spend_cost(fighter: Dictionary, cost: int, source_id: String = "") -> Dictionary:
	if cost < 0:
		return _invalid("invalid_stamina_cost", fighter)
	if not fighter.has("stamina") or not _is_numeric(fighter["stamina"]):
		return _invalid("invalid_stamina", fighter)
	var current := float(fighter["stamina"])
	if current < float(cost):
		return _invalid("insufficient_stamina", fighter)
	var updated := fighter.duplicate(true)
	updated["stamina"] = current - float(cost)
	return {
		"status": "resolved",
		"errors": [],
		"action_id": source_id,
		"cost": cost,
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
		"explicit_cost_override_allowed": true,
		"explicit_cost_authority": "combat_skill_effect_resolver",
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
