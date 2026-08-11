extends RefCounted

const FINAL_MONTH := 20
const TOTAL_RIVAL_RESULTS := 7
const TOTAL_PLAYER_BOUTS := 9


func evaluate(month: int, gt_summary: Dictionary) -> Dictionary:
	var placement := int(gt_summary.get("placement", 0))
	var medal := str(gt_summary.get("medal", ""))
	var standings_resolved := bool(gt_summary.get("standings_resolved", false))
	var tiebreak_required := bool(gt_summary.get("tiebreak_required", false))
	var player_bouts := int(gt_summary.get("player_bouts", 0))
	var rival_results := int(gt_summary.get("rival_results_registered", 0))
	var expected_medal := _expected_medal(placement)
	var classification_valid := (
		standings_resolved
		and not tiebreak_required
		and placement >= 1
		and placement <= TOTAL_RIVAL_RESULTS + 1
		and medal == expected_medal
	)
	var eligible_month := month >= FINAL_MONTH
	var can_finalize := eligible_month and classification_valid
	return {
		"month": month,
		"final_month": FINAL_MONTH,
		"eligible_month": eligible_month,
		"player_series_complete": player_bouts >= TOTAL_PLAYER_BOUTS,
		"rival_results_complete": rival_results == TOTAL_RIVAL_RESULTS,
		"standings_resolved": standings_resolved,
		"tiebreak_required": tiebreak_required,
		"classification_valid": classification_valid,
		"can_finalize": can_finalize,
		"pending": eligible_month and not can_finalize,
		"pending_reason":
		_pending_reason(
			eligible_month,
			player_bouts,
			rival_results,
			standings_resolved,
			tiebreak_required,
			classification_valid,
		),
		"placement": placement if classification_valid else 0,
		"medal": medal if classification_valid else "",
		"victory": classification_valid and placement <= 3,
		"result_source": "gt1_classification" if classification_valid else "pending_gt1",
	}


func _pending_reason(
	eligible_month: bool,
	player_bouts: int,
	rival_results: int,
	standings_resolved: bool,
	tiebreak_required: bool,
	classification_valid: bool
) -> String:
	if not eligible_month:
		return "before_final_month"
	if player_bouts < TOTAL_PLAYER_BOUTS:
		return "player_series_incomplete"
	if rival_results != TOTAL_RIVAL_RESULTS:
		return "rival_results_incomplete"
	if tiebreak_required:
		return "tiebreak_pending"
	if not standings_resolved:
		return "standings_unresolved"
	if not classification_valid:
		return "invalid_classification"
	return ""


func _expected_medal(placement: int) -> String:
	match placement:
		1:
			return "gold"
		2:
			return "silver"
		3:
			return "bronze"
		_:
			return ""
