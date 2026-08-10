extends Node

const MonthlyRivalManagementPolicyScript = preload(
	"res://scripts/systems/monthly_rival_management_policy.gd"
)


func run() -> void:
	_test_contract_blocks_legacy_rng_and_gt1_mutation()
	_test_known_operations_are_quarantined()
	print("Monthly rival management policy: OK")


func _test_contract_blocks_legacy_rng_and_gt1_mutation() -> void:
	var policy = MonthlyRivalManagementPolicyScript.new()
	var contract: Dictionary = policy.get_contract()
	assert(contract.get("legacy_operation_execution_allowed") == false)
	assert(contract.get("legacy_retaliation_rng_allowed") == false)
	assert(contract.get("legacy_gladiator_power_mutation_allowed") == false)
	assert(contract.get("gt1_combat_snapshot_mutation_allowed") == false)
	assert(contract.get("gt1_standings_mutation_allowed") == false)
	assert(contract.get("invent_monthly_costs_allowed") == false)
	assert(contract.get("invent_monthly_risk_allowed") == false)
	assert(contract.get("invent_monthly_cadence_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _test_known_operations_are_quarantined() -> void:
	var policy = MonthlyRivalManagementPolicyScript.new()
	for operation_id in [
		"scout",
		"steal_plans",
		"poison_supplies",
		"bribe_guard",
		"spread_rumors",
	]:
		var reason: String = policy.get_operation_block_reason(operation_id)
		assert(not reason.is_empty())
		assert(reason.contains("cuarentena"))
