extends Node

const MonthlyNonGTActivityPolicyScript = preload(
	"res://scripts/systems/monthly_non_gt_activity_policy.gd"
)


func _ready() -> void:
	var policy = MonthlyNonGTActivityPolicyScript.new()
	_test_management_only_months(policy)
	_test_gt1_months(policy)
	_test_legacy_competitions(policy)
	_test_design_blocked_objectives(policy)
	_test_contract(policy)
	print("Monthly non-GT activity policy: OK")
	get_tree().quit(0)


func _test_management_only_months(policy) -> void:
	for month in [1, 6, 12, 14, 15, 17, 18, 19]:
		var result: Dictionary = policy.evaluate_month(month)
		assert(result.get("mode") == "management_only")
		assert(result.get("arena_activity_approved") == false)
		assert(result.get("non_gt_combat_required") == false)
		assert(result.get("non_gt_combat_optional") == false)
		assert(result.get("legacy_non_gt_schedule_allowed") == false)
		assert(result.get("design_pending") == true)


func _test_gt1_months(policy) -> void:
	for month in [13, 16, 20]:
		var result: Dictionary = policy.evaluate_month(month)
		assert(result.get("mode") == "gt1")
		assert(result.get("gt1_month") == true)
		assert(result.get("arena_activity_approved") == true)
		assert(result.get("campaign_combat_progress_source") == "gt1_combat_v1")


func _test_legacy_competitions(policy) -> void:
	assert(policy.is_legacy_non_gt_competition("underworld"))
	assert(policy.is_legacy_non_gt_competition("official_minor"))
	assert(not policy.is_legacy_non_gt_competition("grand_tournament"))


func _test_design_blocked_objectives(policy) -> void:
	for objective_id in ["first_fight", "first_victory", "three_victories"]:
		assert(policy.is_objective_design_blocked(objective_id))
		assert(not policy.get_objective_block_reason(objective_id).is_empty())
	assert(not policy.is_objective_design_blocked("basic_preparation"))
	assert(not policy.is_objective_design_blocked("gt1_medal"))


func _test_contract(policy) -> void:
	var contract: Dictionary = policy.get_contract()
	assert(contract.get("non_gt_mode") == "management_only")
	assert(contract.get("legacy_non_gt_schedule_allowed") == false)
	assert(contract.get("campaign_combat_progress_source") == "gt1_combat_v1")
	assert(contract.get("invent_arena_rules_allowed") == false)
	assert(contract.get("save_version_change_required") == false)
