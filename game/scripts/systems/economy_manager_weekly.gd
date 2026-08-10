extends "res://scripts/systems/economy_manager.gd"

signal monthly_economy_processed(report: Dictionary)
# Compatibility signal only. It mirrors the same monthly result.
signal weekly_economy_processed(report: Dictionary)

const MonthlyOperatingCostCalculatorScript = preload(
	"res://scripts/core/monthly_operating_cost_calculator.gd"
)

var last_processed_month: int = 0
var last_monthly_report: Dictionary = {}


func get_sponsor(sponsor_id: String) -> Dictionary:
	var data := super.get_sponsor(sponsor_id)
	# Sponsor balance remains compatibility-only until its monthly values are frozen.
	data["duration_months"] = maxi(
		0, int(data.get("duration_months", data.get("duration_weeks", data.get("duration", 0))))
	)
	data["monthly_income"] = maxi(
		0, int(data.get("monthly_income", data.get("weekly_income", data.get("daily_income", 0))))
	)
	data["duration_weeks"] = data["duration_months"]
	data["weekly_income"] = data["monthly_income"]
	data["monthly_balance_status"] = "legacy_compatibility_pending_freeze"
	return data


func get_loan_product(loan_id: String) -> Dictionary:
	var data := super.get_loan_product(loan_id)
	data["term_months"] = maxi(
		0, int(data.get("term_months", data.get("term_weeks", data.get("term", 0))))
	)
	data["term_weeks"] = data["term_months"]
	data["monthly_balance_status"] = "legacy_compatibility_pending_freeze"
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
	var month := GameState.get_month()
	if last_processed_month == month and not last_monthly_report.is_empty():
		var cached := last_monthly_report.duplicate(true)
		cached["duplicate_call_ignored"] = true
		return cached

	var operating_costs := get_monthly_operating_cost_breakdown()
	var report := {
		"period": "month",
		"month": month,
		"week": month,
		"income": 0,
		"expenses": 0,
		"operating_costs": 0,
		# Legacy report aliases. The frozen model no longer splits costs into the
		# inherited building-maintenance and wage formulas.
		"maintenance": 0,
		"wages": 0,
		"sponsor_income": 0,
		"loan_payments": 0,
		"missed_payments": 0,
		"expired_contracts": [],
		"paid_loans": [],
		"bankruptcy_level": 0,
		"operating_cost_breakdown": operating_costs.duplicate(true),
		"duplicate_call_ignored": false,
		"legacy_daily_formula_used": false,
		"legacy_weekly_formula_used": false,
		"sponsor_balance_status": "legacy_compatibility_pending_freeze",
		"loan_balance_status": "legacy_compatibility_pending_freeze",
	}
	if operating_costs.get("status") != "ready":
		report["processing_blocked"] = true
		report["processing_error"] = str(
			operating_costs.get("reason", "monthly_operating_costs_unavailable")
		)
		push_error("No se pudieron calcular los costos operativos mensuales canónicos.")
		return report

	var operating_total := int(operating_costs.get("total", 0))
	report["operating_costs"] = operating_total
	report["maintenance"] = operating_total
	report["expenses"] = operating_total
	_pay_or_default(operating_total, "Costos operativos mensuales", report)

	_normalize_contracts()
	for contract in active_contracts.duplicate():
		var income := int(contract.get("monthly_income", 0))
		report["sponsor_income"] += income
		report["income"] += income
		_add_income(income, "Ingreso mensual de %s" % contract.get("name", "Patrocinador"))
		contract["months_remaining"] = maxi(0, int(contract.get("months_remaining", 1)) - 1)
		if int(contract.get("months_remaining", 0)) <= 0:
			report["expired_contracts"].append(contract.get("name", "Patrocinador"))
			active_contracts.erase(contract)
	_normalize_contracts()

	_normalize_loans()
	for loan in active_loans.duplicate():
		var payment := mini(int(loan.get("installment", 0)), int(loan.get("remaining", 0)))
		if GameState.denarii >= payment:
			GameState.denarii -= payment
			loan["remaining"] = maxi(0, int(loan.get("remaining", 0)) - payment)
			loan["months_remaining"] = maxi(0, int(loan.get("months_remaining", 0)) - 1)
			report["loan_payments"] += payment
			report["expenses"] += payment
			_record_entry(-payment, "Cuota mensual de %s" % loan.get("name", "préstamo"))
			if int(loan.get("remaining", 0)) <= 0:
				report["paid_loans"].append(loan.get("name", "Préstamo"))
				active_loans.erase(loan)
		else:
			loan["missed"] = int(loan.get("missed", 0)) + 1
			loan["remaining"] = int(ceil(float(loan.get("remaining", 0)) * 1.03))
			missed_payments += 1
			report["missed_payments"] += 1
			_record_entry(0, "Cuota mensual impaga de %s" % loan.get("name", "préstamo"))
	_normalize_loans()

	_update_monthly_bankruptcy_state()
	report["bankruptcy_level"] = get_bankruptcy_level()
	_normalize_ledger()
	last_processed_month = month
	last_monthly_report = report.duplicate(true)
	GameState.resources_changed.emit()
	economy_changed.emit()
	monthly_economy_processed.emit(report.duplicate(true))
	weekly_economy_processed.emit(report.duplicate(true))
	# Inherited signal is a compatibility observer only; it is not another tick.
	daily_economy_processed.emit(report.duplicate(true))
	return report


func process_week() -> Dictionary:
	return process_month()


func process_day() -> Dictionary:
	return process_month()


func get_monthly_population_snapshot() -> Dictionary:
	var slave_count := 0
	var gladiator_count := 0
	for person in RosterManager.get_people():
		match str(person.role):
			"slave":
				slave_count += 1
			"gladiator":
				gladiator_count += 1
	var beast_count := OwnedBeastRegistry.get_owned_count()
	return {
		"slave_count": slave_count,
		"gladiator_count": gladiator_count,
		"beast_count": beast_count,
		"slave_count_source": "RosterManager.people",
		"gladiator_count_source": "RosterManager.people",
		"beast_count_source": "OwnedBeastRegistry.owned_beasts",
		"beast_count_source_ready": true,
	}


func get_monthly_operating_cost_breakdown() -> Dictionary:
	var population := get_monthly_population_snapshot()
	var calculator = MonthlyOperatingCostCalculatorScript.new()
	var breakdown: Dictionary = (
		calculator
		. calculate(
			int(population.get("slave_count", 0)),
			int(population.get("gladiator_count", 0)),
			int(population.get("beast_count", 0)),
		)
	)
	breakdown["slave_count_source"] = population.get("slave_count_source", "")
	breakdown["gladiator_count_source"] = population.get("gladiator_count_source", "")
	breakdown["beast_count_source"] = population.get("beast_count_source", "")
	breakdown["beast_count_source_ready"] = population.get("beast_count_source_ready", false)
	return breakdown


func get_monthly_operating_costs() -> int:
	var breakdown := get_monthly_operating_cost_breakdown()
	return int(breakdown.get("total", 0)) if breakdown.get("status") == "ready" else 0


func get_monthly_fixed_costs() -> int:
	# Compatibility name retained for existing presenters/projections.
	return get_monthly_operating_costs()


func get_weekly_fixed_costs() -> int:
	return get_monthly_operating_costs()


func get_daily_fixed_costs() -> int:
	# Parent API compatibility only. It must never restore the old daily formula.
	return get_monthly_operating_costs()


func get_monthly_projection() -> Dictionary:
	_normalize_contracts()
	_normalize_loans()
	var sponsor_income := 0
	for contract in active_contracts:
		sponsor_income += int(contract.get("monthly_income", 0))
	var loan_payments := 0
	for loan in active_loans:
		loan_payments += mini(int(loan.get("installment", 0)), int(loan.get("remaining", 0)))
	var operating_breakdown := get_monthly_operating_cost_breakdown()
	var operating_costs := int(operating_breakdown.get("total", 0))
	return {
		"period": "month",
		"month": GameState.get_month(),
		"income": sponsor_income,
		"expenses": operating_costs + loan_payments,
		"operating_costs": operating_costs,
		"operating_cost_breakdown": operating_breakdown,
		# Compatibility fields retained for callers written before Part 2.
		"fixed_costs": operating_costs,
		"maintenance_and_wages": operating_costs,
		"loan_payments": loan_payments,
		"sponsor_income": sponsor_income,
		"net": sponsor_income - operating_costs - loan_payments,
		"debt": get_total_debt(),
		"legacy_daily_formula_used": false,
		"legacy_weekly_formula_used": false,
		"sponsor_balance_status": "legacy_compatibility_pending_freeze",
		"loan_balance_status": "legacy_compatibility_pending_freeze",
	}


func get_weekly_projection() -> Dictionary:
	return get_monthly_projection()


func get_summary() -> Dictionary:
	var data := super.get_summary()
	var operating_breakdown := get_monthly_operating_cost_breakdown()
	data["monthly_operating_costs"] = int(operating_breakdown.get("total", 0))
	data["monthly_operating_cost_breakdown"] = operating_breakdown
	data["monthly_fixed_costs"] = data["monthly_operating_costs"]
	data["monthly_projection"] = get_monthly_projection()
	data["insolvency_months"] = maxi(0, insolvency_days)
	data["last_processed_month"] = last_processed_month
	data["sponsor_balance_status"] = "legacy_compatibility_pending_freeze"
	data["loan_balance_status"] = "legacy_compatibility_pending_freeze"
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
	data["last_processed_month"] = last_processed_month
	data["last_monthly_report"] = last_monthly_report.duplicate(true)
	return data


func import_state(data: Dictionary) -> void:
	super.import_state(data)
	if data.has("insolvency_months"):
		insolvency_days = maxi(0, int(data.get("insolvency_months", insolvency_days)))
	elif data.has("insolvency_weeks"):
		insolvency_days = maxi(0, int(data.get("insolvency_weeks", insolvency_days)))
	last_processed_month = maxi(0, int(data.get("last_processed_month", 0)))
	var saved_report: Variant = data.get("last_monthly_report", {})
	last_monthly_report = saved_report.duplicate(true) if saved_report is Dictionary else {}
	_normalize_contracts()
	_normalize_loans()
	_normalize_ledger()
	economy_changed.emit()


func _update_monthly_bankruptcy_state() -> void:
	if GameState.denarii <= 0 and not active_loans.is_empty():
		insolvency_days += 1
	elif GameState.denarii < get_monthly_operating_costs():
		insolvency_days = maxi(0, insolvency_days - 1)
	else:
		insolvency_days = 0
	var level := get_bankruptcy_level()
	if level > 0:
		bankruptcy_warning.emit(level, get_bankruptcy_message())


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
