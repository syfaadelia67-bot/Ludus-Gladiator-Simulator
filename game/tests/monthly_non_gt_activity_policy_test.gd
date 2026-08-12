extends Node

const MonthlyNonGTActivityPolicyScript = preload(
	"res://scripts/systems/monthly_non_gt_activity_policy.gd"
)


func _ready() -> void:
	var policy = MonthlyNonGTActivityPolicyScript.new()
	_test_regular_arena_months(policy)
	_test_gt1_months(policy)
	_test_canonical_competitions(policy)
	_test_retired_demo_objectives(policy)
	_test_contract(policy)
	print("Monthly non-GT activity policy: OK")
	get_tree().quit(0)


func _test_regular_arena_months(policy) -> void:
	for month in [1, 6, 12, 14, 15, 17, 18, 19]:
		var result: Dictionary = policy.evaluate_month(month)
		assert(result.get("mode") == "management_plus_arena")
		assert(result.get("gt1_month") == false)
		assert(result.get("arena_activity_approved") == true)
		assert(result.get("non_gt_combat_required") == false)
		assert(result.get("non_gt_combat_optional") == true)
		assert(result.get("underworld_available") == true)
		assert(result.get("official_minor_available") == true)
		assert(result.get("canonical_non_gt_schedule_allowed") == true)
		assert(result.get("legacy_non_gt_schedule_allowed") == false)
		assert(result.get("design_pending") == false)
		assert(result.get("demo_loop_frozen") == true)
		assert(result.get("full_game_non_gt_arena_deferred") == false)


func _test_gt1_months(policy) -> void:
	for month in [13, 16, 20]:
		var result: Dictionary = policy.evaluate_month(month)
		assert(result.get("mode") == "gt1_plus_arena")
		assert(result.get("gt1_month") == true)
		assert(result.get("arena_activity_approved") == true)
		assert(result.get("non_gt_combat_optional") == true)
		assert(result.get("underworld_available") == true)
		assert(result.get("official_minor_available") == false)
		assert(result.get("campaign_combat_progress_source") == "gt1_combat_v1")
		assert(result.get("design_pending") == false)


func _test_canonical_competitions(policy) -> void:
	assert(policy.is_canonical_non_gt_competition("underworld"))
	assert(policy.is_canonical_non_gt_competition("official_minor"))
	assert(not policy.is_canonical_non_gt_competition("grand_tournament"))
	assert(not policy.is_legacy_non_gt_competition("underworld"))
	assert(not policy.is_legacy_non_gt_competition("official_minor"))


func _test_retired_demo_objectives(policy) -> void:
	for objective_id in ["first_fight", "first_victory", "three_victories"]:
		assert(policy.is_objective_retired_from_demo(objective_id))
		assert(not policy.is_objective_design_blocked(objective_id))
		assert(policy.get_objective_block_reason(objective_id).is_empty())
	assert(not policy.is_objective_retired_from_demo("basic_preparation"))
	assert(not policy.is_objective_retired_from_demo("gt1_medal"))


func _test_contract(policy) -> void:
	var contract: Dictionary = policy.get_contract()
	var retired := contract.get("retired_demo_objectives", []) as Array
	var competitions := contract.get("canonical_non_gt_competitions", []) as Array
	assert(contract.get("status") == "frozen")
	assert(contract.get("authority") == "monthly_non_gt_activity_policy")
	assert(contract.get("scope") == "demo_months_1_to_20")
	assert(contract.get("non_gt_mode") == "management_plus_arena")
	assert(contract.get("non_gt_combat_required") == false)
	assert(contract.get("non_gt_combat_optional") == true)
	assert(contract.get("underworld_available_every_month") == true)
	assert(contract.get("official_minor_available_on_non_gt_months") == true)
	assert(contract.get("demo_loop_frozen") == true)
	assert(contract.get("full_game_non_gt_arena_deferred") == false)
	assert(contract.get("canonical_non_gt_schedule_allowed") == true)
	assert(contract.get("legacy_non_gt_schedule_allowed") == false)
	assert(competitions == ["underworld", "official_minor"])
	assert(contract.get("campaign_combat_progress_source") == "gt1_combat_v1")
	assert(retired == ["first_fight", "first_victory", "three_victories"])
	assert(contract.get("replacement_objectives_required") == false)
	assert(contract.get("invent_arena_rules_allowed") == false)
	assert(contract.get("save_version_change_required") == false)
