extends Node


func _ready() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/systems/campaign_manager.gd")

	assert(source.contains("const DEMO_FINAL_MONTH := 20"))
	assert(source.contains("const DEMO_FINAL_WEEK := DEMO_FINAL_MONTH"))
	assert(source.contains("var final_combat_resolved: bool = false"))
	assert(source.contains("func _evaluate_campaign_finale()"))
	assert(source.contains("TournamentManager.is_gt1_complete()"))
	assert(source.contains("TournamentManager.get_gt1_summary()"))
	assert(source.contains('str(gt_summary.get("medal", ""))'))
	assert(source.contains('"gt1_medal"'))
	assert(source.contains('"grand_tournament": TournamentManager.get_gt1_summary()'))
	assert(source.contains('"final_combat_resolved": final_combat_resolved'))
	assert(
		source.contains('final_combat_resolved = bool(data.get("final_combat_resolved", false))')
	)
	assert(not source.contains("LEGACY_DEMO_WIN_TARGET"))
	assert(not source.contains("total_wins >= 6"))

	var progress_start := source.find("func evaluate_progress()")
	var progress_end := source.find("func _evaluate_campaign_finale()")
	var progress_body := source.substr(progress_start, progress_end - progress_start)
	assert(not progress_body.contains("campaign_finished.emit"))
	assert(not progress_body.contains("campaign_over = true"))

	print("Campaign GT I finale contract: OK")
	get_tree().quit()
