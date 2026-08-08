extends Node


func _ready() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/systems/campaign_manager.gd")

	assert(source.contains("const DEMO_FINAL_MONTH := 20"))
	assert(source.contains("const DEMO_FINAL_WEEK := DEMO_FINAL_MONTH"))
	assert(source.contains("var final_combat_resolved: bool = false"))
	assert(source.contains("if GameState.get_month() >= DEMO_FINAL_MONTH:"))
	assert(source.contains("final_combat_resolved = true"))
	assert(source.contains("func _evaluate_campaign_finale()"))
	assert(source.contains("not final_combat_resolved"))
	assert(source.contains("_evaluate_campaign_finale()"))
	assert(source.contains("cierre competitivo del mes XX"))
	assert(source.contains("GameState.get_month() >= DEMO_FINAL_MONTH"))
	assert(source.contains("\"final_combat_resolved\": final_combat_resolved"))
	assert(
		source.contains(
			"final_combat_resolved = bool(data.get(\"final_combat_resolved\", false))"
		)
	)
	assert(source.contains("LEGACY_DEMO_WIN_TARGET"))
	assert(source.contains("next tournament migration replaces this"))
	assert(not source.contains("GameState.get_week() > DEMO_FINAL_WEEK and total_wins < 6"))

	var progress_start := source.find("func evaluate_progress()")
	var progress_end := source.find("func _evaluate_campaign_finale()")
	var progress_body := source.substr(progress_start, progress_end - progress_start)
	assert(not progress_body.contains("campaign_finished.emit"))
	assert(not progress_body.contains("campaign_over = true"))

	print("Campaign month-XX finale compatibility contract: OK")
	get_tree().quit()
