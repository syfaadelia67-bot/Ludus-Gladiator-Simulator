extends RefCounted

const GT1_MONTHS := [13, 16, 20]
const CANONICAL_NON_GT_COMPETITIONS := ["underworld", "official_minor"]
const RETIRED_DEMO_OBJECTIVES := ["first_fight", "first_victory", "three_victories"]


func evaluate_month(month: int) -> Dictionary:
	var resolved_month := maxi(1, month)
	var is_gt1 := GT1_MONTHS.has(resolved_month)
	return {
		"status": "frozen",
		"period": "month",
		"month": resolved_month,
		"mode": "gt1_plus_arena" if is_gt1 else "management_plus_arena",
		"gt1_month": is_gt1,
		"arena_activity_approved": true,
		"non_gt_combat_required": false,
		"non_gt_combat_optional": true,
		"underworld_available": true,
		"official_minor_available": not is_gt1,
		"canonical_non_gt_schedule_allowed": true,
		"legacy_non_gt_schedule_allowed": false,
		"campaign_combat_progress_source": "gt1_combat_v1",
		"approved_management_surfaces":
		[
			"roster",
			"estate",
			"market",
			"equipment",
			"economy",
			"monthly_events",
			"arena",
		],
		"design_pending": false,
		"design_pending_reason": "",
		"demo_loop_frozen": true,
		"full_game_non_gt_arena_deferred": false,
	}


func is_canonical_non_gt_competition(competition: String) -> bool:
	return CANONICAL_NON_GT_COMPETITIONS.has(competition)


func is_legacy_non_gt_competition(_competition: String) -> bool:
	# Compatibility API. The old non-GT competitions are now canonical monthly content.
	return false


func is_objective_retired_from_demo(objective_id: String) -> bool:
	return RETIRED_DEMO_OBJECTIVES.has(objective_id)


func is_objective_design_blocked(objective_id: String) -> bool:
	# Compatibility API: retired objectives are no longer exposed as blocked demo goals.
	return false if RETIRED_DEMO_OBJECTIVES.has(objective_id) else false


func get_objective_block_reason(_objective_id: String) -> String:
	return ""


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"authority": "monthly_non_gt_activity_policy",
		"period": "month",
		"scope": "demo_months_1_to_20",
		"gt1_months": GT1_MONTHS.duplicate(),
		"non_gt_mode": "management_plus_arena",
		"non_gt_combat_required": false,
		"non_gt_combat_optional": true,
		"underworld_available_every_month": true,
		"official_minor_available_on_non_gt_months": true,
		"demo_loop_frozen": true,
		"full_game_non_gt_arena_deferred": false,
		"canonical_non_gt_schedule_allowed": true,
		"legacy_non_gt_schedule_allowed": false,
		"canonical_non_gt_competitions": CANONICAL_NON_GT_COMPETITIONS.duplicate(),
		"campaign_combat_progress_source": "gt1_combat_v1",
		"retired_demo_objectives": RETIRED_DEMO_OBJECTIVES.duplicate(),
		"replacement_objectives_required": false,
		"invent_arena_rules_allowed": false,
		"save_version_change_required": false,
	}
