extends Node

const DemoPreAssetReadinessScript = preload("res://scripts/core/demo_pre_asset_readiness.gd")


func _ready() -> void:
	DataRepository.load_all()
	var readiness = DemoPreAssetReadinessScript.new()
	var snapshot: Dictionary = readiness.evaluate()
	assert(snapshot.get("status") == "blocked")
	assert(snapshot.get("ready") == false)
	assert(snapshot.get("final_assets_allowed") == false)
	assert(int(snapshot.get("blocker_count", 0)) > 0)
	var codes := readiness.get_blocker_codes()
	_assert_known_blockers(codes)
	_assert_contract(readiness.get_contract())
	print("Demo pre-asset readiness report: OK · blockers=%d" % codes.size())
	get_tree().quit(0)


func _assert_known_blockers(codes: Array[String]) -> void:
	assert(codes.has("rival_combat_v1_snapshots_missing"))
	assert(codes.has("beast_combat_v1_stats_missing"))
	assert(codes.has("beast_combat_v1_adapter_missing"))
	assert(codes.has("building_upgrade_cost_pending:mine"))
	assert(codes.has("canonical_skill_mechanics_not_frozen"))
	assert(not codes.has("canonical_skill_progression_reconciliation"))
	assert(codes.has("monthly_economy_runtime"))
	assert(codes.has("monthly_market_cadence"))
	assert(codes.has("monthly_roster_work_recovery"))
	assert(codes.has("monthly_event_cadence"))
	assert(codes.has("monthly_rival_management"))
	assert(codes.has("monthly_planning_turn_closure"))
	assert(not codes.has("legacy_combat_manager_quarantine"))
	assert(codes.has("playable_combat_v1_ui"))
	assert(codes.has("gt1_rival_results_provider"))
	assert(codes.has("months_without_gt1_loop"))
	assert(codes.has("in_progress_combat_save_policy"))
	assert(codes.has("month_20_end_to_end_gate"))


func _assert_contract(contract: Dictionary) -> void:
	assert(contract.get("final_assets_require_zero_blockers") == true)
	assert(contract.get("legacy_combat_authority_allowed") == false)
	assert(contract.get("legacy_weekly_authority_allowed") == false)
	assert(contract.get("invent_missing_balance_allowed") == false)
	assert(contract.get("save_version_change_required") == false)
