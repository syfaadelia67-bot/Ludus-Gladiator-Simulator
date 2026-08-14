extends SceneTree


func _initialize() -> void:
	var script_text := FileAccess.get_file_as_string("res://scripts/ui/tournaments_panel.gd")

	assert(
		script_text.contains(
			"TournamentManager.grand_tournament_changed.connect(_on_grand_tournament_changed)"
		)
	)
	assert(script_text.contains("TournamentManager.get_gt1_summary()"))
	assert(script_text.contains('summary.get("player_bouts", 0)'))
	assert(script_text.contains('summary.get("player_wins", 0)'))
	assert(script_text.contains('summary.get("player_points", 0)'))
	assert(script_text.contains('summary.get("encounter_progress", {})'))
	assert(script_text.contains('progress.get("13", 0)'))
	assert(script_text.contains('progress.get("16", 0)'))
	assert(script_text.contains('progress.get("20", 0)'))
	assert(script_text.contains('summary.get("tiebreak_required", false)'))
	assert(script_text.contains('summary.get("standings_resolved", false)'))
	assert(script_text.contains('summary.get("placement", 0)'))
	assert(script_text.contains('summary.get("medal", "")'))
	assert(script_text.contains('summary.get("rival_results_registered", 0)'))
	assert(script_text.contains("Clasificación final: pendiente."))
	assert(not script_text.contains("register_gt1_rival_result("))

	print("GT I tournaments authoritative progress presentation contract: OK")
	quit()
