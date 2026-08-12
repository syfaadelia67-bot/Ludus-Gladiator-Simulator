extends SceneTree


func _initialize() -> void:
	var finance := EconomyManager.get_finance_scope_contract()
	assert(finance.get("status") == "frozen")
	assert(finance.get("sponsor_contract_creation_enabled") == false)
	assert(finance.get("loan_origination_enabled") == false)
	assert(finance.get("legacy_finance_state_read_only") == true)
	assert(finance.get("invent_missing_balance_allowed") == false)

	var before_denarii := GameState.denarii
	var before_contracts := EconomyManager.active_contracts.size()
	var before_loans := EconomyManager.active_loans.size()
	assert(not EconomyManager.sign_contract("local_merchant"))
	assert(not EconomyManager.take_loan("small"))
	assert(GameState.denarii == before_denarii)
	assert(EconomyManager.active_contracts.size() == before_contracts)
	assert(EconomyManager.active_loans.size() == before_loans)

	var sponsor := EconomyManager.get_sponsor("local_merchant")
	var loan := EconomyManager.get_loan_product("small")
	assert(sponsor.get("monthly_authority") == false)
	assert(sponsor.get("demo_available") == false)
	assert(loan.get("monthly_authority") == false)
	assert(loan.get("demo_available") == false)
	print("Monthly finance fail-closed boundary: OK")
	quit(0)
