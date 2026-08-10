extends RefCounted

const GT1_MONTHS := [13, 16, 20]
const LEGACY_NON_GT_COMPETITIONS := ["underworld", "official_minor"]
const DESIGN_BLOCKED_OBJECTIVES := ["first_fight", "first_victory", "three_victories"]


func evaluate_month(month: int) -> Dictionary:
	var resolved_month := maxi(1, month)
	var is_gt1 := GT1_MONTHS.has(resolved_month)
	return {
		"status": "frozen",
		"period": "month",
		"month": resolved_month,
		"mode": "gt1" if is_gt1 else "management_only",
		"gt1_month": is_gt1,
		"arena_activity_approved": is_gt1,
		"non_gt_combat_required": false,
		"non_gt_combat_optional": false,
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
		],
		"design_pending": not is_gt1,
		"design_pending_reason":
		(
			"Las oportunidades de Arena fuera del GT I todavía requieren reglas congeladas."
			if not is_gt1
			else ""
		),
	}


func is_legacy_non_gt_competition(competition: String) -> bool:
	return LEGACY_NON_GT_COMPETITIONS.has(competition)


func is_objective_design_blocked(objective_id: String) -> bool:
	return DESIGN_BLOCKED_OBJECTIVES.has(objective_id)


func get_objective_block_reason(objective_id: String) -> String:
	if not is_objective_design_blocked(objective_id):
		return ""
	return (
		"Este objetivo dependía de combates fuera del Gran Torneo de Roma. "
		+ "Permanece en pausa hasta congelar el loop de Arena de los meses sin GT I."
	)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"period": "month",
		"gt1_months": GT1_MONTHS.duplicate(),
		"non_gt_mode": "management_only",
		"non_gt_combat_required": false,
		"non_gt_combat_optional": false,
		"legacy_non_gt_schedule_allowed": false,
		"legacy_non_gt_competitions": LEGACY_NON_GT_COMPETITIONS.duplicate(),
		"campaign_combat_progress_source": "gt1_combat_v1",
		"design_blocked_objectives": DESIGN_BLOCKED_OBJECTIVES.duplicate(),
		"invent_arena_rules_allowed": false,
		"save_version_change_required": false,
	}
