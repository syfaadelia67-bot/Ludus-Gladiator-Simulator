extends SceneTree

const EconomyManagerScript = preload("res://scripts/systems/economy_manager_weekly.gd")


func _initialize() -> void:
	var manager = EconomyManagerScript.new()
	var finance := manager.get_monthly_runtime_contract()
	assert(finance.get("status") == "frozen")
	assert(finance.get("sponsor_demo_available") == false)
	assert(finance.get("loan_demo_available") == false)
	assert(finance.get("bankruptcy_demo_available") == false)
	assert(finance.get("unfrozen_actions_fail_closed") == true)
	assert(finance.get("invent_unfrozen_values_allowed") == false)

	var before_contracts := manager.active_contracts.size()
	var before_loans := manager.active_loans.size()
	var before_serial := manager.serial
	assert(not manager.sign_contract("local_merchant"))
	assert(not manager.take_loan("small"))
	assert(manager.active_contracts.size() == before_contracts)
	assert(manager.active_loans.size() == before_loans)
	assert(manager.serial == before_serial)

	var sponsor := manager.get_sponsor("local_merchant")
	var loan := manager.get_loan_product("small")
	assert(sponsor.get("monthly_authority") == false)
	assert(sponsor.get("demo_available") == false)
	assert(loan.get("monthly_authority") == false)
	assert(loan.get("demo_available") == false)
	manager.free()
	print("Monthly finance fail-closed boundary: OK")
	quit(0)
