extends "res://scripts/systems/economy_manager.gd"

signal monthly_economy_processed(report: Dictionary)
signal weekly_economy_processed(report: Dictionary)


func get_sponsor(sponsor_id: String) -> Dictionary:
	var data := super.get_sponsor(sponsor_id)
	if data.is_empty():
		return data
	data["monthly_balance_status"] = "pending_monthly_design"
	data["legacy_compatibility_only"] = true
	return data


func get_loan_product(loan_id: String) -> Dictionary:
	var data := super.get_loan_product(loan_id)
	if data.is_empty():
		return data
	data["monthly_balance_status"] = "pending_monthly_design"
	data["legacy_compatibility_only"] = true
	return data


func process_month() -> Dictionary:
	var report := super.process_month()
	monthly_economy_processed.emit(report.duplicate(true))
	weekly_economy_processed.emit(report.duplicate(true))
	return report


func process_week() -> Dictionary:
	return process_month()


func process_day() -> Dictionary:
	return process_month()


func get_monthly_operating_costs() -> int:
	return int(get_monthly_operating_cost_breakdown().get("total", 0))


func get_monthly_fixed_costs() -> int:
	return get_monthly_operating_costs()


func get_weekly_fixed_costs() -> int:
	return get_monthly_operating_costs()


func get_weekly_projection() -> Dictionary:
	return get_monthly_projection()


func get_contract() -> Dictionary:
	return {
		"status": "compatibility_only",
		"canonical_authority": "monthly_economy_runtime",
		"monthly_parent": "economy_manager",
		"weekly_scheduler_authority": false,
		"daily_scheduler_authority": false,
		"sponsor_balance_authority": false,
		"loan_balance_authority": false,
		"save_version_change_required": false,
	}
