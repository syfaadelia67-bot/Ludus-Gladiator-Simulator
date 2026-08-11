extends Node

const MonthlyRivalManagementPolicyScript = preload(
	"res://scripts/systems/monthly_rival_management_policy.gd"
)


func run() -> void:
	_test_contract_freezes_authored_monthly_balance()
	_test_operation_catalog_matches_authored_values()
	_test_neutral_profile_uses_authored_fallbacks()
	print("Monthly rival management policy: OK")


func _test_contract_freezes_authored_monthly_balance() -> void:
	var policy = MonthlyRivalManagementPolicyScript.new()
	var contract: Dictionary = policy.get_contract()
	var baseline := contract.get("management_baseline", {}) as Dictionary
	var retaliation := contract.get("retaliation_rules", {}) as Dictionary
	assert(contract.get("status") == "frozen")
	assert(contract.get("authority") == "monthly_rival_management_policy")
	assert(contract.get("period") == "month")
	assert(contract.get("process_frequency") == "exactly_once_per_month")
	assert(contract.get("migration_mode") == "one_legacy_turn_equals_one_monthly_turn")
	assert(contract.get("canonical_rival_identity_source") == "DataRepository.rival_ludi")
	assert(int(contract.get("canonical_rival_count", 0)) == 7)
	assert(contract.get("management_baseline_source") == "legacy_explicit_fallbacks")
	assert(int(baseline.get("wealth", 0)) == 50)
	assert(int(baseline.get("security", 0)) == 50)
	assert(int(baseline.get("prestige", 0)) == 50)
	assert(int(baseline.get("relation", -1)) == 0)
	assert(int(baseline.get("suspicion", -1)) == 0)
	assert(int(contract.get("operation_count", 0)) == 5)
	assert(contract.get("player_initiated_operations_enabled") == true)
	assert(contract.get("operation_auto_tick_enabled") == false)
	assert(contract.get("monthly_retaliation_tick_enabled") == true)
	assert(contract.get("legacy_daily_scheduler_is_authority") == false)
	assert(contract.get("legacy_operation_execution_allowed") == false)
	assert(contract.get("legacy_retaliation_rng_allowed") == false)
	assert(contract.get("monthly_retaliation_rng_enabled") == true)
	assert(contract.get("management_gladiator_power_mutation_enabled") == true)
	assert(contract.get("gladiator_power_is_combat_v1_authority") == false)
	assert(contract.get("legacy_gladiator_power_mutation_allowed") == false)
	assert(contract.get("gt1_combat_snapshot_mutation_allowed") == false)
	assert(contract.get("gt1_standings_mutation_allowed") == false)
	assert(int(retaliation.get("hostility_heat_decay", 0)) == 1)
	assert(int(retaliation.get("relation_threshold", 0)) == -45)
	assert(is_equal_approx(float(retaliation.get("base_chance", 0.0)), 0.10))
	assert(int(retaliation.get("denarii_loss_min", 0)) == 35)
	assert(int(retaliation.get("denarii_loss_max", 0)) == 110)
	assert(int(retaliation.get("food_loss_min", 0)) == 4)
	assert(int(retaliation.get("food_loss_max", 0)) == 12)
	assert(contract.get("invent_monthly_costs_allowed") == false)
	assert(contract.get("invent_monthly_risk_allowed") == false)
	assert(contract.get("invent_monthly_cadence_allowed") == false)
	assert(contract.get("proportional_legacy_scaling_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _test_operation_catalog_matches_authored_values() -> void:
	var policy = MonthlyRivalManagementPolicyScript.new()
	var expected := {
		"scout": [0, 20, 12],
		"steal_plans": [12, 35, 28],
		"poison_supplies": [20, 55, 42],
		"bribe_guard": [8, 90, 22],
		"spread_rumors": [15, 50, 34],
	}
	assert(policy.get_operation_ids().size() == 5)
	for operation_id in expected.keys():
		var data := policy.get_operation(str(operation_id))
		var values := expected[operation_id] as Array
		assert(int(data.get("intel_cost", -1)) == int(values[0]))
		assert(int(data.get("denarii_cost", -1)) == int(values[1]))
		assert(int(data.get("risk", -1)) == int(values[2]))
		assert(policy.get_operation_block_reason(str(operation_id)).is_empty())
	assert(not policy.get_operation_block_reason("unknown").is_empty())


func _test_neutral_profile_uses_authored_fallbacks() -> void:
	var policy = MonthlyRivalManagementPolicyScript.new()
	var profile := policy.build_management_profile({"id": "flavianus", "name": "Ludus Flavianus"})
	assert(profile.get("id") == "flavianus")
	assert(profile.get("name") == "Ludus Flavianus")
	assert(int(profile.get("wealth", 0)) == 50)
	assert(int(profile.get("security", 0)) == 50)
	assert(int(profile.get("prestige", 0)) == 50)
	assert(int(profile.get("relation", -1)) == 0)
	assert(int(profile.get("intel", -1)) == 0)
	assert(int(profile.get("suspicion", -1)) == 0)
	assert(int(profile.get("gladiator_power", 0)) == 50)
	assert(profile.get("combat_v1_authority") == false)
