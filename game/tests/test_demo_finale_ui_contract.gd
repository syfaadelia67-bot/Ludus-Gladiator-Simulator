extends Node


func run() -> void:
	var result_presenter := FileAccess.get_file_as_string(
		"res://scripts/ui/campaign_result_presenter.gd"
	)
	var read_only_presenter := FileAccess.get_file_as_string(
		"res://scripts/ui/completed_campaign_read_only_presenter.gd"
	)
	var inspector := FileAccess.get_file_as_string(
		"res://scripts/core/save_compatibility_inspector.gd"
	)
	var start_screen := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")
	var localization := FileAccess.get_file_as_string("res://localization/shared.es.po")

	assert(result_presenter.contains('summary.get("finale", {})'))
	assert(result_presenter.contains('finale.get("classification_valid", false)'))
	assert(result_presenter.contains('finale.get("placement", 0)'))
	assert(result_presenter.contains('finale.get("medal", "")'))
	assert(result_presenter.contains('summary.get("grand_tournament", {})'))
	assert(result_presenter.contains("GameState.get_month()"))
	assert(result_presenter.contains('summary.get("final_month", CampaignManager.DEMO_FINAL_MONTH)'))
	assert(not result_presenter.contains("GameState.get_week()"))
	assert(not result_presenter.contains('summary.get("final_week", 16)'))
	assert(result_presenter.contains("CAMPAIGN_RESULT_READ_ONLY_BUTTON"))
	assert(result_presenter.contains("func _enter_read_only()"))
	assert(result_presenter.contains("overlay.visible = false"))

	assert(read_only_presenter.contains("CampaignManager.campaign_over"))
	assert(read_only_presenter.contains("CAMPAÑA FINALIZADA · MODO CONSULTA"))
	assert(start_screen.contains("START_VIEW_FINAL_RESULT"))
	assert(start_screen.contains("SaveManager.load_game()"))
	assert(result_presenter.contains("SaveManager.load_completed.connect"))
	assert(result_presenter.contains("_show_loaded_result_if_needed"))

	for metadata_field in [
		"final_combat_resolved",
		"gt1_player_points",
		"gt1_player_wins",
		"gt1_player_bouts",
		"gt1_placement",
		"gt1_medal",
		"gt1_standings_resolved",
		"gt1_tiebreak_required",
	]:
		assert(inspector.contains('"%s"' % metadata_field))

	for key in [
		"CAMPAIGN_RESULT_TITLE_VICTORY",
		"CAMPAIGN_RESULT_TITLE_FINISHED",
		"CAMPAIGN_RESULT_DETAILS",
		"CAMPAIGN_RESULT_GT1",
		"CAMPAIGN_RESULT_READ_ONLY_BUTTON",
		"CAMPAIGN_RESULT_RETURN_MENU_BUTTON",
		"GT1_MEDAL_GOLD",
		"GT1_MEDAL_SILVER",
		"GT1_MEDAL_BRONZE",
		"GT1_MEDAL_NONE",
	]:
		assert(localization.contains('msgid "%s"' % key))

	print("Demo finale UI/read-only contract: OK")
