extends Node

const DemoFinalePolicyScript = preload("res://scripts/systems/demo_finale_policy.gd")


func run() -> void:
	var policy = DemoFinalePolicyScript.new()

	var before_final := policy.evaluate(19, _summary(true, false, 1, "gold", 9, 7))
	assert(not bool(before_final.get("can_finalize", true)))
	assert(str(before_final.get("pending_reason", "")) == "before_final_month")

	var incomplete_series := policy.evaluate(20, _summary(false, false, 0, "", 8, 7))
	assert(not bool(incomplete_series.get("can_finalize", true)))
	assert(str(incomplete_series.get("pending_reason", "")) == "player_series_incomplete")

	var missing_rivals := policy.evaluate(20, _summary(false, false, 0, "", 9, 6))
	assert(not bool(missing_rivals.get("can_finalize", true)))
	assert(str(missing_rivals.get("pending_reason", "")) == "rival_results_incomplete")

	var pending_tiebreak := policy.evaluate(20, _summary(false, true, 0, "", 9, 7))
	assert(not bool(pending_tiebreak.get("can_finalize", true)))
	assert(bool(pending_tiebreak.get("pending", false)))
	assert(str(pending_tiebreak.get("pending_reason", "")) == "tiebreak_pending")

	var invalid_medal := policy.evaluate(20, _summary(true, false, 1, "silver", 9, 7))
	assert(not bool(invalid_medal.get("can_finalize", true)))
	assert(str(invalid_medal.get("pending_reason", "")) == "invalid_classification")

	var champion := policy.evaluate(20, _summary(true, false, 1, "gold", 9, 7))
	assert(bool(champion.get("can_finalize", false)))
	assert(bool(champion.get("victory", false)))
	assert(int(champion.get("placement", 0)) == 1)
	assert(str(champion.get("medal", "")) == "gold")
	assert(str(champion.get("result_source", "")) == "gt1_classification")

	var fourth := policy.evaluate(20, _summary(true, false, 4, "", 9, 7))
	assert(bool(fourth.get("can_finalize", false)))
	assert(not bool(fourth.get("victory", true)))
	assert(str(fourth.get("medal", "not-empty")) == "")

	print("Demo finale policy test passed")


func _summary(
	resolved: bool, tiebreak: bool, placement: int, medal: String, bouts: int, rivals: int
) -> Dictionary:
	return {
		"standings_resolved": resolved,
		"tiebreak_required": tiebreak,
		"placement": placement,
		"medal": medal,
		"player_bouts": bouts,
		"rival_results_registered": rivals,
	}
