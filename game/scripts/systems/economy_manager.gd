# Compatibility facade: Save/UI public methods stay stable.
# New economy logic belongs in focused runtimes.
# gdlint: disable=max-public-methods
extends Node

signal economy_changed
signal daily_economy_processed(report: Dictionary)
signal contract_signed(contract: Dictionary)
signal contract_failed(reason: String)
signal loan_taken(loan: Dictionary)
signal loan_failed(reason: String)
signal bankruptcy_warning(level: int, message: String)

const MonthlyEconomyRuntimeScript = preload("res://scripts/systems/monthly_economy_runtime.gd")
const PENDING_SPONSOR_REASON := "Patrocinadores fuera de demo: balance mensual pendiente."
const PENDING_LOAN_REASON := "Préstamos fuera de demo: balance mensual y quiebra pendientes."

# Legacy sponsor/loan catalogs remain available for Save v14 compatibility only.
const SPONSORS := {
	"local_merchant":
	{
		"name": "Mercaderes del Foro",
		"duration": 10,
		"upfront": 120,
		"daily_income": 18,
		"required_reputation": 0,
		"victory_bonus": 35,
		"failure_penalty": 20,
	},
	"patrician_house":
	{
		"name": "Casa Patricia",
		"duration": 14,
		"upfront": 250,
		"daily_income": 30,
		"required_reputation": 12,
		"victory_bonus": 60,
		"failure_penalty": 45,
	},
	"imperial_circle":
	{
		"name": "Círculo Imperial",
		"duration": 20,
		"upfront": 500,
		"daily_income": 55,
		"required_reputation": 35,
		"victory_bonus": 110,
		"failure_penalty": 90,
	},
}

const LOAN_PRODUCTS := {
	"small": {"name": "Préstamo menor", "principal": 250, "interest": 1.20, "term": 12},
	"medium": {"name": "Préstamo mercantil", "principal": 600, "interest": 1.28, "term": 18},
	"large": {"name": "Préstamo patricio", "principal": 1200, "interest": 1.38, "term": 24},
}

var active_contracts: Array[Dictionary] = []
var active_loans: Array[Dictionary] = []
var ledger: Array[Dictionary] = []
var missed_payments: int = 0
var insolvency_days: int = 0
var total_income: int = 0
var total_expenses: int = 0
var serial: int = 0
var last_processed_month: int = 0
var last_monthly_report: Dictionary = {}

var _monthly_runtime = MonthlyEconomyRuntimeScript.new()


func get_sponsor_ids() -> Array[String]:
	var ids: Array[String] = []
	for sponsor_id in SPONSORS.keys():
		ids.append(str(sponsor_id))
	return ids


func get_sponsor(sponsor_id: String) -> Dictionary:
	var data: Dictionary = SPONSORS.get(sponsor_id, {}).duplicate(true)
	data["id"] = sponsor_id
	data["eligible"] = false
	data["demo_available"] = false
	data["monthly_authority"] = false
	data["unavailable_reason"] = PENDING_SPONSOR_REASON
	return data


func get_loan_ids() -> Array[String]:
	var ids: Array[String] = []
	for loan_id in LOAN_PRODUCTS.keys():
		ids.append(str(loan_id))
	return ids


func get_loan_product(loan_id: String) -> Dictionary:
	var data: Dictionary = LOAN_PRODUCTS.get(loan_id, {}).duplicate(true)
	data["id"] = loan_id
	data["demo_available"] = false
	data["monthly_authority"] = false
	data["unavailable_reason"] = PENDING_LOAN_REASON
	return data


func sign_contract(sponsor_id: String) -> bool:
	if not SPONSORS.has(sponsor_id):
		contract_failed.emit("El patrocinador seleccionado no existe.")
		return false
	contract_failed.emit(PENDING_SPONSOR_REASON)
	return false


func take_loan(loan_id: String) -> bool:
	if not LOAN_PRODUCTS.has(loan_id):
		loan_failed.emit("El préstamo seleccionado no existe.")
		return false
	loan_failed.emit(PENDING_LOAN_REASON)
	return false


func get_finance_scope_contract() -> Dictionary:
	return {
		"status": "frozen",
		"scope": "demo_monthly_finance_boundary",
		"sponsor_contract_creation_enabled": false,
		"loan_origination_enabled": false,
		"legacy_finance_state_read_only": true,
		"sponsor_monthly_balance_status": "pending_design",
		"loan_monthly_balance_status": "pending_design",
		"bankruptcy_monthly_balance_status": "pending_design",
		"invent_missing_balance_allowed": false,
		"save_version_change_required": false,
	}


func get_monthly_population_snapshot() -> Dictionary:
	var slave_count := 0
	var gladiator_count := 0
	for person in RosterManager.get_people():
		if person == null:
			continue
		match str(person.role):
			"slave":
				slave_count += 1
			"gladiator":
				gladiator_count += 1
	var beast_count := OwnedBeastRegistry.get_owned_count()
	return {
		"status": "ready",
		"slave_count": slave_count,
		"gladiator_count": gladiator_count,
		"beast_count": beast_count,
		"beast_count_source": "OwnedBeastRegistry",
		"beast_count_source_ready": true,
	}


func get_monthly_operating_cost_breakdown() -> Dictionary:
	var population := get_monthly_population_snapshot()
	var result: Dictionary = (
		_monthly_runtime
		. calculate_monthly_cost(
			int(population.get("slave_count", 0)),
			int(population.get("gladiator_count", 0)),
			int(population.get("beast_count", 0)),
		)
	)
	if result.get("status") != "ready":
		return result
	return {
		"status": "ready",
		"period": "month",
		"fixed_expense": int(result.get("fixed_cost", 0)),
		"slave_cost": int(result.get("slave_cost", 0)),
		"gladiator_cost": int(result.get("gladiator_cost", 0)),
		"beast_cost": int(result.get("beast_cost", 0)),
		"total": int(result.get("total_cost", 0)),
		"population": population.duplicate(true),
		"authority": "monthly_economy_runtime",
		"legacy_daily_formula_used": false,
	}


func get_monthly_projection() -> Dictionary:
	var breakdown := get_monthly_operating_cost_breakdown()
	var fixed_costs := int(breakdown.get("total", 0))
	return {
		"period": "month",
		"fixed_costs": fixed_costs,
		"sponsor_income": 0,
		"loan_payments": 0,
		"net": -fixed_costs,
		"sponsor_balance_status": "pending_monthly_design",
		"loan_balance_status": "pending_monthly_design",
		"bankruptcy_balance_status": "pending_monthly_design",
		"legacy_daily_formula_used": false,
	}


func process_month() -> Dictionary:
	var month := maxi(1, int(GameState.day))
	if last_processed_month == month and not last_monthly_report.is_empty():
		var cached := last_monthly_report.duplicate(true)
		cached["duplicate_call_ignored"] = true
		return cached

	var population := get_monthly_population_snapshot()
	var resolved: Dictionary = (
		_monthly_runtime
		. process_month(
			maxi(0, int(GameState.denarii)),
			int(population.get("slave_count", 0)),
			int(population.get("gladiator_count", 0)),
			int(population.get("beast_count", 0)),
		)
	)
	if resolved.get("status") != "resolved":
		return resolved

	var before := int(GameState.denarii)
	var after := int(resolved.get("denarii_after", before))
	var paid := int(resolved.get("paid", 0))
	GameState.denarii = after
	if paid > 0:
		_record_entry(-paid, "Costos operativos mensuales · Mes %d" % month)
	var missed_this_month := 0
	if int(resolved.get("unpaid", 0)) > 0:
		missed_payments += 1
		missed_this_month = 1

	last_processed_month = month
	last_monthly_report = {
		"status": "resolved",
		"period": "month",
		"month": month,
		"denarii_before": before,
		"denarii_after": after,
		"operating_costs": int(resolved.get("total_cost", 0)),
		"paid": paid,
		"unpaid": int(resolved.get("unpaid", 0)),
		"missed_payments": missed_this_month,
		"duplicate_call_ignored": false,
		"sponsor_income": 0,
		"loan_payments": 0,
		"sponsor_balance_status": "pending_monthly_design",
		"loan_balance_status": "pending_monthly_design",
		"bankruptcy_balance_status": "pending_monthly_design",
		"legacy_daily_formula_used": false,
	}
	GameState.resources_changed.emit()
	economy_changed.emit()
	daily_economy_processed.emit(last_monthly_report.duplicate(true))
	return last_monthly_report.duplicate(true)


# Compatibility aliases. Neither owns scheduler authority.
func process_day() -> Dictionary:
	return process_month()


func process_week() -> Dictionary:
	return process_month()


func register_combat_result(victory: bool) -> void:
	# Preserve counters for legacy Save v14 contracts without granting payout authority.
	for contract in active_contracts:
		if victory:
			contract["victories"] = int(contract.get("victories", 0)) + 1
		else:
			contract["defeats"] = int(contract.get("defeats", 0)) + 1
	economy_changed.emit()


func get_daily_fixed_costs() -> int:
	# Compatibility alias for UI callers; the returned value is monthly.
	return int(get_monthly_operating_cost_breakdown().get("total", 0))


func get_total_debt() -> int:
	var total := 0
	for loan in active_loans:
		total += int(loan.get("remaining", 0))
	return total


func get_bankruptcy_level() -> int:
	# Legacy bankruptcy thresholds are not authoritative in the monthly demo.
	return 0


func get_bankruptcy_message() -> String:
	return "Sponsors, préstamos y quiebra mensual están fuera del alcance funcional de la demo."


func get_summary() -> Dictionary:
	var projection := get_monthly_projection()
	var breakdown := get_monthly_operating_cost_breakdown()
	return {
		"monthly_operating_costs": int(breakdown.get("total", 0)),
		"monthly_operating_cost_breakdown": breakdown.duplicate(true),
		"monthly_fixed_costs": int(projection.get("fixed_costs", 0)),
		"daily_fixed_costs": int(projection.get("fixed_costs", 0)),
		"total_debt": get_total_debt(),
		"contracts": active_contracts.size(),
		"loans": active_loans.size(),
		"sponsor_demo_available": false,
		"loan_demo_available": false,
		"bankruptcy_demo_available": false,
		"sponsor_unavailable_reason": PENDING_SPONSOR_REASON,
		"loan_unavailable_reason": PENDING_LOAN_REASON,
		"missed_payments": missed_payments,
		"insolvency_days": insolvency_days,
		"bankruptcy_level": 0,
		"message": get_bankruptcy_message(),
		"total_income": total_income,
		"total_expenses": total_expenses,
		"last_processed_month": last_processed_month,
	}


func get_monthly_runtime_contract() -> Dictionary:
	var contract := _monthly_runtime.get_contract()
	contract["sponsor_demo_available"] = false
	contract["loan_demo_available"] = false
	contract["bankruptcy_demo_available"] = false
	contract["unfrozen_actions_fail_closed"] = true
	return contract


func export_state() -> Dictionary:
	return {
		"active_contracts": active_contracts.duplicate(true),
		"active_loans": active_loans.duplicate(true),
		"ledger": ledger.duplicate(true),
		"missed_payments": missed_payments,
		"insolvency_days": insolvency_days,
		"total_income": total_income,
		"total_expenses": total_expenses,
		"serial": serial,
		"last_processed_month": last_processed_month,
		"last_monthly_report": last_monthly_report.duplicate(true),
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
	last_processed_month = maxi(0, int(data.get("last_processed_month", 0)))
	var report_value: Variant = data.get("last_monthly_report", {})
	last_monthly_report = (
		(report_value as Dictionary).duplicate(true) if report_value is Dictionary else {}
	)
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
	ledger.push_front(
		{"month": GameState.get_month(), "day": GameState.day, "amount": amount, "reason": reason}
	)
	if ledger.size() > 80:
		ledger.resize(80)
