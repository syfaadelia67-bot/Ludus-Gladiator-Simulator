extends "res://scripts/systems/economy_manager.gd"

signal weekly_economy_processed(report: Dictionary)

func get_sponsor(sponsor_id: String) -> Dictionary:
    var data := super.get_sponsor(sponsor_id)
    data["duration_weeks"] = maxi(0, int(data.get("duration_weeks", data.get("duration", 0))))
    data["weekly_income"] = maxi(0, int(data.get("weekly_income", data.get("daily_income", 0))))
    return data

func get_loan_product(loan_id: String) -> Dictionary:
    var data := super.get_loan_product(loan_id)
    data["term_weeks"] = maxi(0, int(data.get("term_weeks", data.get("term", 0))))
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

func process_week() -> Dictionary:
    var report := super.process_day()
    _normalize_contracts()
    _normalize_loans()
    _normalize_ledger()
    report["period"] = "week"
    report["week"] = GameState.get_week()
    weekly_economy_processed.emit(report.duplicate(true))
    return report

func get_weekly_fixed_costs() -> int:
    return get_daily_fixed_costs()

func get_weekly_projection() -> Dictionary:
    var sponsor_income := 0
    for contract in active_contracts:
        sponsor_income += int(contract.get("weekly_income", contract.get("daily_income", 0)))
    var loan_payments := 0
    for loan in active_loans:
        loan_payments += mini(int(loan.get("installment", 0)), int(loan.get("remaining", 0)))
    var fixed_costs := get_weekly_fixed_costs()
    return {
        "income": sponsor_income,
        "expenses": fixed_costs + loan_payments,
        "fixed_costs": fixed_costs,
        "loan_payments": loan_payments,
        "sponsor_income": sponsor_income,
        "net": sponsor_income - fixed_costs - loan_payments,
        "debt": get_total_debt()
    }

func get_summary() -> Dictionary:
    var data := super.get_summary()
    data["weekly_fixed_costs"] = get_weekly_fixed_costs()
    data["weekly_projection"] = get_weekly_projection()
    data["insolvency_weeks"] = maxi(0, insolvency_days)
    return data

func export_state() -> Dictionary:
    _normalize_contracts()
    _normalize_loans()
    _normalize_ledger()
    var data := super.export_state()
    data["insolvency_weeks"] = maxi(0, insolvency_days)
    return data

func import_state(data: Dictionary) -> void:
    super.import_state(data)
    if data.has("insolvency_weeks"):
        insolvency_days = maxi(0, int(data.get("insolvency_weeks", insolvency_days)))
    _normalize_contracts()
    _normalize_loans()
    _normalize_ledger()
    economy_changed.emit()

func _record_entry(amount: int, reason: String) -> void:
    if amount < 0:
        total_expenses += abs(amount)
    var normalized_reason := reason.replace("Ingreso diario de", "Ingreso semanal de")
    var week := GameState.get_week()
    ledger.push_front({
        "week": week,
        "day": week,
        "amount": amount,
        "reason": normalized_reason
    })
    if ledger.size() > 80:
        ledger.resize(80)

func _normalize_contracts() -> void:
    for contract in active_contracts:
        var weeks := maxi(0, int(contract.get("weeks_remaining", contract.get("days_remaining", 0))))
        var income := maxi(0, int(contract.get("weekly_income", contract.get("daily_income", 0))))
        contract["weeks_remaining"] = weeks
        contract["days_remaining"] = weeks
        contract["weekly_income"] = income
        contract["daily_income"] = income

func _normalize_loans() -> void:
    for loan in active_loans:
        var weeks := maxi(0, int(loan.get("weeks_remaining", loan.get("days_remaining", 0))))
        loan["weeks_remaining"] = weeks
        loan["days_remaining"] = weeks

func _normalize_ledger() -> void:
    for index in range(ledger.size()):
        if not ledger[index] is Dictionary:
            continue
        var entry: Dictionary = ledger[index]
        var week := maxi(1, int(entry.get("week", entry.get("day", 1))))
        entry["week"] = week
        entry["day"] = week
        entry["reason"] = str(entry.get("reason", "Movimiento")).replace("Ingreso diario de", "Ingreso semanal de")
        ledger[index] = entry
