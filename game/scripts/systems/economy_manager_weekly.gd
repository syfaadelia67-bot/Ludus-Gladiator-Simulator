extends "res://scripts/systems/economy_manager.gd"

signal monthly_economy_processed(report: Dictionary)
# Compatibility signal only. It mirrors the same monthly result.
signal weekly_economy_processed(report: Dictionary)


func get_sponsor(sponsor_id: String) -> Dictionary:
	var data := super.get_sponsor(sponsor_id)
	# Legacy duration/income fields remain until Part 2 freezes sponsor balance.
	data["duration_months"] = maxi(
		0, int(data.get("duration_months", data.get("duration_weeks", data.get("duration", 0))))
	)
	data["monthly_income"] = maxi(
		0, int(data.get("monthly_income", data.get("weekly_income", data.get("daily_income", 0))))
	)
	data["duration_weeks"] = data["duration_months"]
	data["weekly_income"] = data["monthly_income"]
	return data


func get_loan_product(loan_id: String) -> Dictionary:
	var data := super.get_loan_product(loan_id)
	data["term_months"] = maxi(
		0, int(data.get("term_months", data.get("term_weeks", data.get("term", 0))))
	)
	data["term_weeks"] = data["term_months"]
	return data


func sign_contract(sponsor_id: String) -> bool:
	var signed := super.sign_contract(sponsor_id)
	if signed:
		_normalize_contracts()
	return signed


func take_loan(loan_id: String) -> bool:
	var taken := super.take_loan(loan_id)
	if taken:
		_normalize_loans()
	return taken


func process_month() -> Dictionary:
	# Part 2 will replace the inherited financial formulas with the frozen monthly
	# operating-cost model. For Part 1 this legacy kernel executes exactly once per
	# canonical month and is never entered through a weekly/day scheduler.
	var report := super.process_day()
	_normalize_contracts()
	_normalize_loans()
	_normalize_ledger()
	report["period"] = "month"
	report["month"] = GameState.get_month()
	report["week"] = GameState.get_month()
	monthly_economy_processed.emit(report.duplicate(true))
	weekly_economy_processed.emit(report.duplicate(true))
	return report


func process_week() -> Dictionary:
	return process_month()


func get_monthly_fixed_costs() -> int:
	# Transitional value only; Part 2 replaces this inherited formula.
	return get_daily_fixed_costs()


func get_weekly_fixed_costs() -> int:
	return get_monthly_fixed_costs()


func get_monthly_projection() -> Dictionary:
	var sponsor_income := 0
	for contract in active_contracts:
		sponsor_income += int(
			contract.get(
				"monthly_income", contract.get("weekly_income", contract.get("daily_income", 0))
			)
		)
	var loan_payments := 0
	for loan in active_loans:
		loan_payments += mini(int(loan.get("installment", 0)), int(loan.get("remaining", 0)))
	var fixed_costs := get_monthly_fixed_costs()
	return {
		"period": "month",
		"month": GameState.get_month(),
		"income": sponsor_income,
		"expenses": fixed_costs + loan_payments,
		"fixed_costs": fixed_costs,
		"maintenance_and_wages": fixed_costs,
		"loan_payments": loan_payments,
		"sponsor_income": sponsor_income,
		"net": sponsor_income - fixed_costs - loan_payments,
		"debt": get_total_debt()
	}


func get_weekly_projection() -> Dictionary:
	return get_monthly_projection()


func get_summary() -> Dictionary:
	var data := super.get_summary()
	data["monthly_fixed_costs"] = get_monthly_fixed_costs()
	data["monthly_projection"] = get_monthly_projection()
	data["insolvency_months"] = maxi(0, insolvency_days)
	# Save-v14 / legacy aliases.
	data["weekly_fixed_costs"] = data["monthly_fixed_costs"]
	data["weekly_projection"] = data["monthly_projection"].duplicate(true)
	data["insolvency_weeks"] = data["insolvency_months"]
	return data


func export_state() -> Dictionary:
	_normalize_contracts()
	_normalize_loans()
	_normalize_ledger()
	var data := super.export_state()
	data["insolvency_months"] = maxi(0, insolvency_days)
	data["insolvency_weeks"] = data["insolvency_months"]
	return data


func import_state(data: Dictionary) -> void:
	super.import_state(data)
	if data.has("insolvency_months"):
		insolvency_days = maxi(0, int(data.get("insolvency_months", insolvency_days)))
	elif data.has("insolvency_weeks"):
		insolvency_days = maxi(0, int(data.get("insolvency_weeks", insolvency_days)))
	_normalize_contracts()
	_normalize_loans()
	_normalize_ledger()
	economy_changed.emit()


func _record_entry(amount: int, reason: String) -> void:
	if amount < 0:
		total_expenses += abs(amount)
	var normalized_reason := reason.replace("Ingreso diario de", "Ingreso mensual de")
	normalized_reason = normalized_reason.replace("Ingreso semanal de", "Ingreso mensual de")
	var month := GameState.get_month()
	ledger.push_front(
		{"month": month, "week": month, "day": month, "amount": amount, "reason": normalized_reason}
	)
	if ledger.size() > 80:
		ledger.resize(80)


func _normalize_contracts() -> void:
	for contract in active_contracts:
		var months := maxi(
			0,
			int(
				contract.get(
					"months_remaining",
					contract.get("weeks_remaining", contract.get("days_remaining", 0))
				)
			),
		)
		var income := maxi(
			0,
			int(
				contract.get(
					"monthly_income", contract.get("weekly_income", contract.get("daily_income", 0))
				)
			),
		)
		contract["months_remaining"] = months
		contract["weeks_remaining"] = months
		contract["days_remaining"] = months
		contract["monthly_income"] = income
		contract["weekly_income"] = income
		contract["daily_income"] = income


func _normalize_loans() -> void:
	for loan in active_loans:
		var months := maxi(
			0,
			int(
				loan.get(
					"months_remaining", loan.get("weeks_remaining", loan.get("days_remaining", 0))
				)
			),
		)
		loan["months_remaining"] = months
		loan["weeks_remaining"] = months
		loan["days_remaining"] = months


func _normalize_ledger() -> void:
	for index in range(ledger.size()):
		if not ledger[index] is Dictionary:
			continue
		var entry: Dictionary = ledger[index]
		var month := maxi(
			1, int(entry.get("month", entry.get("week", entry.get("day", GameState.get_month()))))
		)
		entry["month"] = month
		entry["week"] = month
		entry["day"] = month
		entry["reason"] = str(entry.get("reason", "Movimiento")).replace(
			"Ingreso diario de", "Ingreso mensual de"
		)
		entry["reason"] = str(entry["reason"]).replace("Ingreso semanal de", "Ingreso mensual de")
		ledger[index] = entry
