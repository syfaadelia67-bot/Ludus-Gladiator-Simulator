extends RefCounted

const ACTION_COEFFICIENTS := {
	"light": {"fue": 0.35, "power": 0.55},
	"heavy": {"fue": 0.50, "power": 0.75},
}
const MITIGATION_COEFFICIENTS := {"RES": 0.15, "defense": 0.25}
const MIN_DAMAGE := 1


func resolve_damage(attacker: Dictionary, defender: Dictionary, action_id: String) -> Dictionary:
	if not ACTION_COEFFICIENTS.has(action_id):
		return _invalid("unsupported_damage_action")
	var attacker_errors := _validate_fighter(attacker, "attacker")
	var defender_errors := _validate_fighter(defender, "defender")
	var errors: Array[String] = []
	errors.append_array(attacker_errors)
	errors.append_array(defender_errors)
	if not errors.is_empty():
		return {"status": "invalid", "errors": errors}

	var attacker_stats := attacker.get("stats", {}) as Dictionary
	var defender_stats := defender.get("stats", {}) as Dictionary
	var attacker_equipment := _equipment_snapshot(attacker)
	var defender_equipment := _equipment_snapshot(defender)
	var coefficients := ACTION_COEFFICIENTS[action_id] as Dictionary
	var raw_damage := (
		float(attacker_stats.get("FUE", 0.0)) * float(coefficients.get("fue", 0.0))
		+ float(attacker_equipment.get("power", 0.0)) * float(coefficients.get("power", 0.0))
	)
	var mitigation := (
		float(defender_stats.get("RES", 0.0)) * float(MITIGATION_COEFFICIENTS["RES"])
		+ float(defender_equipment.get("defense", 0.0)) * float(MITIGATION_COEFFICIENTS["defense"])
	)
	var final_damage: int = maxi(MIN_DAMAGE, int(round(raw_damage - mitigation)))
	return {
		"status": "resolved",
		"errors": [],
		"action_id": action_id,
		"raw_damage": raw_damage,
		"mitigation": mitigation,
		"damage": final_damage,
		"attacker_equipment": attacker_equipment.duplicate(true),
		"defender_equipment": defender_equipment.duplicate(true),
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"owner": "combat_simulator",
		"deterministic": true,
		"minimum_damage": MIN_DAMAGE,
		"action_coefficients": ACTION_COEFFICIENTS.duplicate(true),
		"mitigation_coefficients": MITIGATION_COEFFICIENTS.duplicate(true),
		"equipment_missing_means_zero": true,
		"armor_penetration_enabled": false,
	}


func _validate_fighter(fighter: Dictionary, role: String) -> Array[String]:
	var errors: Array[String] = []
	var stats := fighter.get("stats", {}) as Dictionary
	for stat_id in ["FUE", "RES"]:
		if not stats.has(stat_id) or not _is_numeric(stats[stat_id]):
			errors.append("%s stat %s must be numeric" % [role, stat_id])
		elif float(stats[stat_id]) < 0.0:
			errors.append("%s stat %s cannot be negative" % [role, stat_id])
	var equipment := fighter.get("equipment", {}) as Dictionary
	for value_id in ["power", "defense"]:
		if equipment.has(value_id):
			if not _is_numeric(equipment[value_id]):
				errors.append("%s equipment %s must be numeric" % [role, value_id])
			elif float(equipment[value_id]) < 0.0:
				errors.append("%s equipment %s cannot be negative" % [role, value_id])
	return errors


func _equipment_snapshot(fighter: Dictionary) -> Dictionary:
	var equipment := fighter.get("equipment", {}) as Dictionary
	return {
		"power": float(equipment.get("power", 0.0)),
		"defense": float(equipment.get("defense", 0.0)),
	}


func _invalid(error: String) -> Dictionary:
	return {"status": "invalid", "errors": [error]}


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float
