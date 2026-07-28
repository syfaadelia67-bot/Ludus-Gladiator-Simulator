extends Node

signal economy_changed
signal daily_economy_processed(report: Dictionary)
signal contract_signed(contract: Dictionary)
signal contract_failed(reason: String)
signal loan_taken(loan: Dictionary)
signal loan_failed(reason: String)
signal bankruptcy_warning(level: int, message: String)

const SPONSORS := {
    "local_merchant": {
        "name": "Mercaderes del Foro",
        "duration": 10,
        "upfront": 120,
        "daily_income": 18,
        "required_reputation": 0,
        "victory_bonus": 35,
        "failure_penalty": 20
    },
    "patrician_house": {
        "name": "Casa Patricia",
        "duration": 14,
        "upfront": 250,
        "daily_income": 30,
        "required_reputation": 12,
        "victory_bonus": 60,
        "failure_penalty": 45
    },
    "imperial_circle": {
        "name": "Círculo Imperial",
        "duration": 20,
        "upfront": 500,
        "daily_income": 55,
        "required_reputation": 35,
        "victory_bonus": 110,
        "failure_penalty": 90
    }
}

const LOAN_PRODUCTS := {
    "small": {"name":"Préstamo menor","principal":250,"interest":1.20,"term":12},
    "medium": {"name":"Préstamo mercantil","principal":600,"interest":1.28,"term":18},
    "large": {"name":"Préstamo patricio","principal":1200,"interest":1.38,"term":24}
}

var active_contracts: Array[Dictionary] = []
var active_loans: Array[Dictionary] = []
var ledger: Array[Dictionary] = []
var missed_payments: int = 0
var insolvency_days: int = 0
var total_income: int = 0
var total_expenses: int = 0
var serial: int = 0

func get_sponsor_ids() -> Array[String]:
    var ids: Array[String] = []
    for sponsor_id in SPONSORS.keys():
        ids.append(str(sponsor_id))
    return ids

func get_sponsor(sponsor_id: String) -> Dictionary:
    var data: Dictionary = SPONSORS.get(sponsor_id, {}).duplicate(true)
    data["id"] = sponsor_id
    data["eligible"] = GameState.reputation >= int(data.get("required_reputation", 999))
    return data

func get_loan_ids() -> Array[String]:
    var ids: Array[String] = []
    for loan_id in LOAN_PRODUCTS.keys():
        ids.append(str(loan_id))
    return ids

func get_loan_product(loan_id: String) -> Dictionary:
    var data: Dictionary = LOAN_PRODUCTS.get(loan_id, {}).duplicate(true)
    data["id"] = loan_id
    return data

func sign_contract(sponsor_id: String) -> bool:
    if not SPONSORS.has(sponsor_id):
        contract_failed.emit("El patrocinador seleccionado no existe.")
        return false
    for contract in active_contracts:
        if str(contract.get("sponsor_id", "")) == sponsor_id:
            contract_failed.emit("Ya existe un contrato activo con este patrocinador.")
            return false
    var sponsor: Dictionary = SPONSORS[sponsor_id]
    var required_reputation := int(sponsor.get("required_reputation", 0))
    if GameState.reputation < required_reputation:
        contract_failed.emit("La reputación del ludus es insuficiente para este contrato.")
        return false
    serial += 1
    var contract := {
        "id": "contract_%d" % serial,
        "sponsor_id": sponsor_id,
        "name": sponsor.get("name", sponsor_id),
        "days_remaining": int(sponsor.get("duration", 10)),
        "daily_income": int(sponsor.get("daily_income", 0)),
        "victory_bonus": int(sponsor.get("victory_bonus", 0)),
        "failure_penalty": int(sponsor.get("failure_penalty", 0)),
        "victories": 0,
        "defeats": 0
    }
    active_contracts.append(contract)
    var upfront := int(sponsor.get("upfront", 0))
    _add_income(upfront, "Anticipo de patrocinio: %s" % sponsor.get("name", sponsor_id))
    contract_signed.emit(contract.duplicate(true))
    economy_changed.emit()
    return true

func take_loan(loan_id: String) -> bool:
    if not LOAN_PRODUCTS.has(loan_id):
        loan_failed.emit("El préstamo seleccionado no existe.")
        return false
    if active_loans.size() >= 3:
        loan_failed.emit("El ludus ya tiene demasiadas deudas activas.")
        return false
    var product: Dictionary = LOAN_PRODUCTS[loan_id]
    serial += 1
    var principal := int(product.get("principal", 0))
    var total_due := int(round(principal * float(product.get("interest", 1.0))))
    var term := int(product.get("term", 12))
    var installment := int(ceil(float(total_due) / float(term)))
    var loan := {
        "id": "loan_%d" % serial,
        "loan_id": loan_id,
        "name": product.get("name", loan_id),
        "principal": principal,
        "total_due": total_due,
        "remaining": total_due,
        "days_remaining": term,
        "installment": installment,
        "missed": 0
    }
    active_loans.append(loan)
    _add_income(principal, "Ingreso por %s" % product.get("name", loan_id))
    loan_taken.emit(loan.duplicate(true))
    economy_changed.emit()
    return true

func process_day() -> Dictionary:
    var report := {
        "income": 0,
        "expenses": 0,
        "maintenance": 0,
        "wages": 0,
        "sponsor_income": 0,
        "loan_payments": 0,
        "missed_payments": 0,
        "expired_contracts": [],
        "paid_loans": [],
        "bankruptcy_level": 0
    }

    var maintenance := _calculate_maintenance()
    var wages := _calculate_wages()
    report.maintenance = maintenance
    report.wages = wages
    report.expenses += maintenance + wages
    _pay_or_default(maintenance + wages, "Mantenimiento y salarios", report)

    for contract in active_contracts.duplicate():
        var income := int(contract.get("daily_income", 0))
        report.sponsor_income += income
        report.income += income
        _add_income(income, "Ingreso diario de %s" % contract.get("name", "Patrocinador"))
        contract["days_remaining"] = int(contract.get("days_remaining", 1)) - 1
        if int(contract.get("days_remaining", 0)) <= 0:
            report.expired_contracts.append(contract.get("name", "Patrocinador"))
            active_contracts.erase(contract)

    for loan in active_loans.duplicate():
        var payment := mini(int(loan.get("installment", 0)), int(loan.get("remaining", 0)))
        if GameState.denarii >= payment:
            GameState.denarii -= payment
            loan["remaining"] = maxi(0, int(loan.get("remaining", 0)) - payment)
            loan["days_remaining"] = maxi(0, int(loan.get("days_remaining", 0)) - 1)
            report.loan_payments += payment
            report.expenses += payment
            _record_entry(-payment, "Cuota de %s" % loan.get("name", "préstamo"))
            if int(loan.get("remaining", 0)) <= 0:
                report.paid_loans.append(loan.get("name", "Préstamo"))
                active_loans.erase(loan)
        else:
            loan["missed"] = int(loan.get("missed", 0)) + 1
            loan["remaining"] = int(ceil(float(loan.get("remaining", 0)) * 1.03))
            missed_payments += 1
            report.missed_payments += 1
            _record_entry(0, "Cuota impaga de %s" % loan.get("name", "préstamo"))

    _update_bankruptcy_state()
    report.bankruptcy_level = get_bankruptcy_level()
    GameState.resources_changed.emit()
    economy_changed.emit()
    daily_economy_processed.emit(report)
    return report

func register_combat_result(victory: bool) -> void:
    for contract in active_contracts:
        if victory:
            contract["victories"] = int(contract.get("victories", 0)) + 1
            _add_income(int(contract.get("victory_bonus", 0)), "Bono por victoria de %s" % contract.get("name", "Patrocinador"))
        else:
            contract["defeats"] = int(contract.get("defeats", 0)) + 1
            var penalty := int(contract.get("failure_penalty", 0))
            _pay_or_default(penalty, "Penalización contractual", {})
    economy_changed.emit()

func _calculate_maintenance() -> int:
    var total := 0
    for building_id in EstateManager.get_building_ids():
        total += EstateManager.get_level(building_id) * 3
    total += EquipmentManager.inventory.size()
    return total

func _calculate_wages() -> int:
    var total := 0
    for person in RosterManager.get_people():
        total += 5 if person.role == "gladiator" else 2
    return total

func _pay_or_default(amount: int, reason: String, report: Dictionary) -> bool:
    if amount <= 0:
        return true
    if GameState.denarii >= amount:
        GameState.denarii -= amount
        _record_entry(-amount, reason)
        return true
    var unpaid := amount - GameState.denarii
    if GameState.denarii > 0:
        _record_entry(-GameState.denarii, "%s (pago parcial)" % reason)
    GameState.denarii = 0
    missed_payments += 1
    if report.has("missed_payments"):
        report.missed_payments = int(report.get("missed_payments", 0)) + 1
    _apply_unpaid_consequences(unpaid)
    return false

func _apply_unpaid_consequences(unpaid: int) -> void:
    GameState.reputation = maxi(0, GameState.reputation - maxi(1, unpaid / 40))
    for person in RosterManager.get_people():
        person.morale = maxi(0, person.morale - 4)
        person.loyalty = maxi(0, person.loyalty - 2)

func _update_bankruptcy_state() -> void:
    if GameState.denarii <= 0 and not active_loans.is_empty():
        insolvency_days += 1
    elif GameState.denarii < get_daily_fixed_costs():
        insolvency_days = maxi(0, insolvency_days - 1)
    else:
        insolvency_days = 0
    var level := get_bankruptcy_level()
    if level > 0:
        bankruptcy_warning.emit(level, get_bankruptcy_message())

func get_daily_fixed_costs() -> int:
    return _calculate_maintenance() + _calculate_wages()

func get_total_debt() -> int:
    var total := 0
    for loan in active_loans:
        total += int(loan.get("remaining", 0))
    return total

func get_bankruptcy_level() -> int:
    if insolvency_days >= 7 or missed_payments >= 6:
        return 3
    if insolvency_days >= 4 or missed_payments >= 3:
        return 2
    if insolvency_days >= 2 or missed_payments >= 1:
        return 1
    return 0

func get_bankruptcy_message() -> String:
    match get_bankruptcy_level():
        3: return "El ludus está al borde de la quiebra y puede perder activos."
        2: return "Los acreedores presionan y la plantilla pierde confianza."
        1: return "La tesorería es frágil y existen pagos atrasados."
        _: return "La economía del ludus es estable."

func get_summary() -> Dictionary:
    return {
        "daily_fixed_costs": get_daily_fixed_costs(),
        "total_debt": get_total_debt(),
        "contracts": active_contracts.size(),
        "loans": active_loans.size(),
        "missed_payments": missed_payments,
        "insolvency_days": insolvency_days,
        "bankruptcy_level": get_bankruptcy_level(),
        "message": get_bankruptcy_message(),
        "total_income": total_income,
        "total_expenses": total_expenses
    }

func export_state() -> Dictionary:
    return {
        "active_contracts": active_contracts.duplicate(true),
        "active_loans": active_loans.duplicate(true),
        "ledger": ledger.duplicate(true),
        "missed_payments": missed_payments,
        "insolvency_days": insolvency_days,
        "total_income": total_income,
        "total_expenses": total_expenses,
        "serial": serial
    }

func import_state(data: Dictionary) -> void:
    active_contracts.assign(data.get("active_contracts", []))
    active_loans.assign(data.get("active_loans", []))
    ledger.assign(data.get("ledger", []))
    missed_payments = maxi(0, int(data.get("missed_payments", 0)))
    insolvency_days = maxi(0, int(data.get("insolvency_days", 0)))
    total_income = maxi(0, int(data.get("total_income", 0)))
    total_expenses = maxi(0, int(data.get("total_expenses", 0)))
    serial = maxi(0, int(data.get("serial", 0)))
    economy_changed.emit()

func _add_income(amount: int, reason: String) -> void:
    if amount <= 0:
        return
    GameState.denarii += amount
    total_income += amount
    _record_entry(amount, reason)

func _record_entry(amount: int, reason: String) -> void:
    if amount < 0:
        total_expenses += abs(amount)
    ledger.push_front({"day":GameState.day,"amount":amount,"reason":reason})
    if ledger.size() > 80:
        ledger.resize(80)
