extends Node

const DemoPreAssetReadinessScript = preload("res://scripts/core/demo_pre_asset_readiness.gd")


func _ready() -> void:
	DataRepository.load_all()
	var readiness = DemoPreAssetReadinessScript.new()
	var snapshot: Dictionary = readiness.evaluate()
	assert(snapshot.get("status") == "blocked")
	assert(snapshot.get("ready") == false)
	assert(snapshot.get("final_assets_allowed") == false)
	assert(snapshot.get("programming_complete_allowed") == false)
	assert(int(snapshot.get("blocker_count", 0)) > 0)
	var codes := readiness.get_blocker_codes()
	_assert_known_blockers(codes)
	_assert_skill_blocker(snapshot)
	_assert_report(readiness, snapshot)
	_assert_contract(readiness.get_contract())
	print("Demo pre-asset readiness report: OK · blockers=%d" % codes.size())
	get_tree().quit(0)


func _assert_known_blockers(codes: Array[String]) -> void:
	assert(not codes.has("rival_combat_v1_snapshots_missing"))
	assert(not codes.has("beast_combat_v1_stats_missing"))
	assert(not codes.has("beast_combat_v1_adapter_missing"))
	assert(codes.has("building_upgrade_cost_pending:mine"))
	assert(codes.has("canonical_skill_mechanics_not_frozen"))
	assert(not codes.has("canonical_skill_progression_reconciliation"))
	assert(codes.has("monthly_economy_runtime"))
	assert(codes.has("monthly_market_cadence"))
	assert(codes.has("monthly_roster_work_recovery"))
	assert(codes.has("monthly_event_cadence"))
	assert(codes.has("monthly_rival_management"))
	assert(not codes.has("monthly_planning_turn_closure"))
	assert(not codes.has("legacy_combat_manager_quarantine"))
	assert(codes.has("playable_combat_v1_ui"))
	assert(codes.has("gt1_rival_results_provider"))
	assert(codes.has("months_without_gt1_loop"))
	assert(not codes.has("in_progress_combat_save_policy"))
	assert(not codes.has("month_20_end_to_end_gate"))


func _assert_skill_blocker(snapshot: Dictionary) -> void:
	assert(DataRepository.get_skill_mechanics_v1().is_empty())
	var blockers := snapshot.get("blockers", []) as Array
	for raw_blocker in blockers:
		if not raw_blocker is Dictionary:
			continue
		var blocker := raw_blocker as Dictionary
		if str(blocker.get("code", "")) != "canonical_skill_mechanics_not_frozen":
			continue
		assert(blocker.get("design_blocked") == true)
		assert(str(blocker.get("reason", "")).contains("Missing mechanics=12"))
		assert(str(blocker.get("reason", "")).contains("missing progression=12"))
		return
	assert(false, "Skill mechanics readiness blocker must be present")


func _assert_report(readiness, snapshot: Dictionary) -> void:
	var report: Dictionary = readiness.get_report()
	assert(report.get("status") == "blocked")
	assert(report.get("clear") == false)
	assert(report.get("programming_complete_allowed") == false)
	assert(report.get("final_assets_allowed") == false)
	assert(int(report.get("blocker_count", -1)) == int(snapshot.get("blocker_count", -2)))
	assert(
		(
			(
				int(report.get("design_blocked_count", 0))
				+ int(report.get("implementation_blocked_count", 0))
			)
			== int(report.get("blocker_count", -1))
		)
	)
	var lines := report.get("lines", []) as Array
	var unresolved := report.get("unresolved_blockers", []) as Array
	assert(lines.size() == int(report.get("blocker_count", -1)))
	assert(unresolved.size() == int(report.get("blocker_count", -1)))
	for code in readiness.get_blocker_codes():
		var found := false
		for line in lines:
			if str(line).begins_with(code + " · "):
				found = true
				break
		assert(found, "Readiness report must list unresolved blocker: %s" % code)
	assert(not readiness.can_declare_programming_complete())


func _assert_contract(contract: Dictionary) -> void:
	assert(contract.get("final_assets_require_zero_blockers") == true)
	assert(contract.get("programming_complete_requires_clear_report") == true)
	assert(contract.get("report_lists_every_blocker") == true)
	assert(contract.get("legacy_combat_authority_allowed") == false)
	assert(contract.get("legacy_weekly_authority_allowed") == false)
	assert(contract.get("invent_missing_balance_allowed") == false)
	assert(contract.get("skill_mechanics_source_fail_closed") == true)
	assert(contract.get("month_20_end_to_end_quality_gate") == "automated_test")
	assert(contract.get("save_version_change_required") == false)
