extends Node

const DemoPreAssetReadinessScript = preload("res://scripts/core/demo_pre_asset_readiness.gd")


func _ready() -> void:
	DataRepository.load_all()
	var readiness = DemoPreAssetReadinessScript.new()
	var snapshot: Dictionary = readiness.evaluate()
	assert(snapshot.get("status") == "ready")
	assert(snapshot.get("ready") == true)
	assert(snapshot.get("final_assets_allowed") == true)
	assert(snapshot.get("programming_complete_allowed") == true)
	assert(int(snapshot.get("blocker_count", -1)) == 0)
	var codes := readiness.get_blocker_codes()
	assert(codes.is_empty())
	_assert_report(readiness, snapshot)
	_assert_contract(readiness.get_contract())
	print("Demo pre-asset readiness report: OK · blockers=0")
	get_tree().quit(0)


func _assert_report(readiness, snapshot: Dictionary) -> void:
	var report: Dictionary = readiness.get_report()
	assert(report.get("status") == "clear")
	assert(report.get("clear") == true)
	assert(report.get("programming_complete_allowed") == true)
	assert(report.get("final_assets_allowed") == true)
	assert(int(report.get("blocker_count", -1)) == 0)
	assert(int(snapshot.get("blocker_count", -1)) == 0)
	assert(int(report.get("design_blocked_count", -1)) == 0)
	assert(int(report.get("implementation_blocked_count", -1)) == 0)
	assert((report.get("lines", []) as Array).is_empty())
	assert((report.get("unresolved_blockers", []) as Array).is_empty())
	assert(readiness.can_declare_programming_complete())


func _assert_contract(contract: Dictionary) -> void:
	assert(contract.get("final_assets_require_zero_blockers") == true)
	assert(contract.get("programming_complete_requires_clear_report") == true)
	assert(contract.get("report_lists_every_blocker") == true)
	assert(contract.get("legacy_combat_authority_allowed") == false)
	assert(contract.get("legacy_weekly_authority_allowed") == false)
	assert(contract.get("invent_missing_balance_allowed") == false)
	assert(contract.get("skill_mechanics_source_fail_closed") == true)
	assert(contract.get("skill_runtime_quality_gate") == "combat_skill_runtime_resolver_contract")
	assert(contract.get("monthly_economy_quality_gate") == "economy_manager_monthly_runtime_contract")
	assert(contract.get("monthly_market_quality_gate") == "market_manager_monthly_policy_contract")
	assert(contract.get("monthly_roster_quality_gate") == "roster_manager_monthly_work_policy_contract")
	assert(contract.get("equipment_quality_gate") == "equipment_runtime_policy_contract")
	assert(contract.get("monthly_event_quality_gate") == "monthly_event_runtime_policy_contract")
	assert(contract.get("monthly_rival_quality_gate") == "monthly_rival_management_policy_contract")
	assert(contract.get("non_gt_loop_quality_gate") == "monthly_non_gt_activity_policy_contract")
	assert(contract.get("gt1_rival_results_provider_quality_gate") == "campaign_owned_contract")
	assert(contract.get("month_20_end_to_end_quality_gate") == "automated_test")
	assert(contract.get("save_version_change_required") == false)
