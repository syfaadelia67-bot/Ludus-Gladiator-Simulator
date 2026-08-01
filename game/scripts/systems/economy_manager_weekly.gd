extends "res://scripts/systems/economy_manager.gd"

func get_weekly_fixed_costs() -> int:
    return get_daily_fixed_costs()

func get_weekly_projection() -> Dictionary:
    var sponsor_income := 0
    for contract in active_contracts:
        sponsor_income += int(contract.get("daily_income", 0))
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
    return data
