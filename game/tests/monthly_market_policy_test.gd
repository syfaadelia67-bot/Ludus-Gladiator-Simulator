extends Node

const MonthlyMarketPolicyScript = preload("res://scripts/systems/monthly_market_policy.gd")


func _ready() -> void:
	var policy = MonthlyMarketPolicyScript.new()
	var contract: Dictionary = policy.get_contract()

	assert(contract.get("status") == "pending_frozen_market_balance")
	assert(contract.get("month_native") == true)
	assert(contract.get("auto_rotation_enabled") == false)
	assert(contract.get("auto_rotation_cadence_months") == null)
	assert(contract.get("manual_equipment_refresh_enabled") == false)
	assert(contract.get("manual_equipment_refresh_cost") == null)
	assert(contract.get("procedural_recruit_generation_enabled") == false)
	assert(contract.get("procedural_equipment_generation_enabled") == false)
	assert(contract.get("legacy_three_turn_cadence_is_authoritative") == false)
	assert(contract.get("legacy_equipment_refresh_cost_is_authoritative") == false)
	assert(contract.get("invent_missing_balance_allowed") == false)
	assert(not policy.can_auto_rotate(1))
	assert(not policy.can_auto_rotate(120))
	assert(not policy.can_manual_refresh_equipment())
	assert(not policy.can_generate_procedural_recruits())
	assert(not policy.can_generate_procedural_equipment())

	print("Monthly market policy fail-closed contract: OK")
	get_tree().quit(0)
