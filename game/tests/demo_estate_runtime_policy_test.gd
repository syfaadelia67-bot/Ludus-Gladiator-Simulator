extends Node

const DemoEstateRuntimePolicyScript = preload("res://scripts/systems/demo_estate_runtime_policy.gd")


func _ready() -> void:
	var policy = DemoEstateRuntimePolicyScript.new()
	var contract: Dictionary = policy.get_contract()
	assert(contract.get("status") == "frozen_demo_estate_runtime_boundary")
	assert((contract.get("demo_building_ids", []) as Array).size() == 7)
	assert(contract.get("demo_max_level") == 3)
	assert(contract.get("full_game_max_level") == 10)
	assert(contract.get("training_numeric_effect_enabled") == false)
	assert(contract.get("recovery_numeric_effect_enabled") == false)
	assert(contract.get("mine_numeric_effect_enabled") == false)
	assert(contract.get("beast_capacity_limit_enabled") == false)
	assert(contract.get("owned_beast_registry_access_enabled") == true)
	assert(contract.get("invent_missing_balance_allowed") == false)
	assert(policy.get_effect_status("barracks").get("structural_effect_active") == true)
	assert(policy.get_effect_status("forge").get("structural_effect_active") == true)
	assert(policy.get_effect_status("training_yard").get("numeric_balance_ready") == false)
	assert(policy.get_effect_status("infirmary").get("numeric_balance_ready") == false)
	assert(policy.get_effect_status("mine").get("numeric_balance_ready") == false)
	assert(
		policy.get_effect_status("mine").get("pending_balance_effect")
		== "monthly_production_balance"
	)
	assert(policy.get_effect_status("beast_area").get("numeric_balance_ready") == false)
	assert(not policy.can_apply_training_numeric_effect())
	assert(not policy.can_apply_recovery_numeric_effect())
	assert(not policy.can_apply_mine_numeric_effect())
	assert(not policy.can_enforce_beast_capacity())
	print("Demo estate runtime policy: OK")
	get_tree().quit(0)