extends RefCounted

const FIXED_MONTHLY_COST := 88
const SLAVE_MONTHLY_COST := 5
const GLADIATOR_MONTHLY_COST := 20
const BEAST_MONTHLY_COST := 10


func calculate_monthly_cost(slave_count: int, gladiator_count: int, beast_count: int) -> Dictionary:
	if slave_count < 0 or gladiator_count < 0 or beast_count < 0:
		return {
			"status": "rejected",
			"reason": "negative_roster_count",
			"total_cost": 0,
		}
	var slave_cost := slave_count * SLAVE_MONTHLY_COST
	var gladiator_cost := gladiator_count * GLADIATOR_MONTHLY_COST
	var beast_cost := beast_count * BEAST_MONTHLY_COST
	return {
		"status": "ready",
		"fixed_cost": FIXED_MONTHLY_COST,
		"slave_count": slave_count,
		"gladiator_count": gladiator_count,
		"beast_count": beast_count,
		"slave_cost": slave_cost,
		"gladiator_cost": gladiator_cost,
		"beast_cost": beast_cost,
		"total_cost": FIXED_MONTHLY_COST + slave_cost + gladiator_cost + beast_cost,
	}


func process_month(denarii: int, slave_count: int, gladiator_count: int, beast_count: int) -> Dictionary:
	if denarii < 0:
		return {
			"status": "rejected",
			"reason": "negative_denarii",
			"denarii_before": denarii,
			"denarii_after": denarii,
		}
	var cost := calculate_monthly_cost(slave_count, gladiator_count, beast_count)
	if cost.get("status") != "ready":
		return {
			"status": "rejected",
			"reason": str(cost.get("reason", "invalid_cost_input")),
			"denarii_before": denarii,
			"denarii_after": denarii,
		}
	var total_cost := int(cost.get("total_cost", 0))
	var paid := mini(denarii, total_cost)
	var unpaid := maxi(0, total_cost - paid)
	return {
		"status": "resolved",
		"period": "month",
		"denarii_before": denarii,
		"denarii_after": maxi(0, denarii - total_cost),
		"total_cost": total_cost,
		"paid": paid,
		"unpaid": unpaid,
		"fully_paid": unpaid == 0,
		"cost_breakdown": cost.duplicate(true),
		"sponsor_income_applied": 0,
		"loan_payment_applied": 0,
		"bankruptcy_penalty_applied": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"authority": "monthly_economy_runtime",
		"period": "month",
		"process_frequency": "exactly_once_per_closed_month",
		"fixed_monthly_cost": FIXED_MONTHLY_COST,
		"slave_monthly_cost": SLAVE_MONTHLY_COST,
		"gladiator_monthly_cost": GLADIATOR_MONTHLY_COST,
		"beast_monthly_cost": BEAST_MONTHLY_COST,
		"daily_economy_is_authority": false,
		"legacy_weekly_economy_is_authority": false,
		"sponsor_balance_frozen": false,
		"loan_balance_frozen": false,
		"bankruptcy_balance_frozen": false,
		"invent_unfrozen_values_allowed": false,
		"save_version_change_required": false,
	}
