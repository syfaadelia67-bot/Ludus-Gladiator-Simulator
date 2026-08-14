extends RefCounted


func calculate(slave_count: int, gladiator_count: int, beast_count: int) -> Dictionary:
	var rule := DataRepository.get_economy_rule("monthly_operating_costs")
	if rule.is_empty():
		return _rejected("missing_monthly_operating_cost_rule")
	if slave_count < 0 or gladiator_count < 0 or beast_count < 0:
		return _rejected("negative_population_count")

	var fixed_expense := int(rule.get("fixed_expense", -1))
	var slave_unit_cost := int(rule.get("slave_maintenance", -1))
	var gladiator_unit_cost := int(rule.get("gladiator_maintenance", -1))
	var beast_unit_cost := int(rule.get("beast_maintenance", -1))
	if fixed_expense < 0 or slave_unit_cost < 0 or gladiator_unit_cost < 0 or beast_unit_cost < 0:
		return _rejected("invalid_monthly_operating_cost_rule")

	var slave_cost := slave_count * slave_unit_cost
	var gladiator_cost := gladiator_count * gladiator_unit_cost
	var beast_cost := beast_count * beast_unit_cost
	return {
		"status": "ready",
		"reason": "",
		"period": "month",
		"fixed_expense": fixed_expense,
		"slave_count": slave_count,
		"slave_unit_cost": slave_unit_cost,
		"slave_cost": slave_cost,
		"gladiator_count": gladiator_count,
		"gladiator_unit_cost": gladiator_unit_cost,
		"gladiator_cost": gladiator_cost,
		"beast_count": beast_count,
		"beast_unit_cost": beast_unit_cost,
		"beast_cost": beast_cost,
		"total": fixed_expense + slave_cost + gladiator_cost + beast_cost,
		"rule_source": "DataRepository.monthly_operating_costs",
		"legacy_daily_formula_used": false,
		"legacy_weekly_formula_used": false,
		"save_version_change_required": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"period": "month",
		"rule_source": "DataRepository.monthly_operating_costs",
		"fixed_expense": 88,
		"slave_maintenance": 5,
		"gladiator_maintenance": 20,
		"beast_maintenance": 10,
		"legacy_daily_formula_allowed": false,
		"legacy_weekly_formula_allowed": false,
		"save_version_change_required": false,
	}


func _rejected(reason: String) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"period": "month",
		"total": 0,
		"rule_source": "DataRepository.monthly_operating_costs",
		"legacy_daily_formula_used": false,
		"legacy_weekly_formula_used": false,
		"save_version_change_required": false,
	}
