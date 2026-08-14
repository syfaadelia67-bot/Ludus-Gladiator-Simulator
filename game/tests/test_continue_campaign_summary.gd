extends Node


func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")

	assert(source.contains("func _format_save_summary"))
	assert(source.contains("owner_name"))
	assert(source.contains("owner_title"))
	assert(source.contains("START_ACTIVE_CAMPAIGN_SUMMARY"))
	assert(source.contains("START_CAMPAIGN_FINISHED_SUMMARY"))
	assert(source.contains("START_RESULT_VICTORY"))
	assert(source.contains("START_RESULT_DEFEAT"))
	assert(source.contains("CampaignManager.get_chapter_for_month(month)"))
	assert(source.contains("CampaignManager.DEMO_FINAL_MONTH"))
	assert(source.contains("TournamentManager.get_gt1_encounter(month)"))
	assert(source.contains("func _activity_name_for_month"))
	assert(source.contains("BATTLE_OFFICIAL_TOURNAMENT"))
	assert(source.contains("BATTLE_WEEKLY_EXHIBITION"))
	assert(not source.contains("BATTLE_BEAST_HUNT"))
	assert(not source.contains("BATTLE_UNDERGROUND"))
	assert(not source.contains("func _battle_name_for_week"))
	assert(source.contains("SAVE_COMPATIBILITY_INSPECTOR"))
	assert(source.contains("func _inspect_save"))
	assert(source.contains('save_inspection.get("loadable"'))
	assert(source.contains('save_inspection.get("message"'))
	assert(source.contains('save_inspection.get("metadata"'))

	print("Continue campaign monthly summary contract: OK")
