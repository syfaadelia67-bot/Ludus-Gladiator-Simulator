extends SceneTree


func _initialize() -> void:
	var manager := root.get_node_or_null("EconomyManager")
	assert(manager != null, "EconomyManager autoload must be available in the project runtime")
	var finance: Dictionary = manager.call("get_monthly_runtime_contract")
	assert(finance.get("status") == "frozen")
	assert(finance.get("sponsor_demo_available") == false)
	assert(finance.get("loan_demo_available") == false)
	assert(finance.get("bankruptcy_demo_available") == false)
	assert(finance.get("unfrozen_actions_fail_closed") == true)
	assert(finance.get("invent_unfrozen_values_allowed") == false)

	var active_contracts: Array = manager.get("active_contracts")
	var active_loans: Array = manager.get("active_loans")
	var before_contracts := active_contracts.size()
	var before_loans := active_loans.size()
	var before_serial := int(manager.get("serial"))
	assert(not bool(manager.call("sign_contract", "local_merchant")))
	assert(not bool(manager.call("take_loan", "small")))
	assert((manager.get("active_contracts") as Array).size() == before_contracts)
	assert((manager.get("active_loans") as Array).size() == before_loans)
	assert(int(manager.get("serial")) == before_serial)

	var sponsor: Dictionary = manager.call("get_sponsor", "local_merchant")
	var loan: Dictionary = manager.call("get_loan_product", "small")
	assert(sponsor.get("monthly_authority") == false)
	assert(sponsor.get("demo_available") == false)
	assert(loan.get("monthly_authority") == false)
	assert(loan.get("demo_available") == false)
	print("Monthly finance fail-closed boundary: OK")
	quit(0)
