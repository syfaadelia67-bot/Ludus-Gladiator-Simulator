extends Node


func run() -> void:
	var start_screen := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")
	var spanish := FileAccess.get_file_as_string("res://localization/es.po")

	assert(start_screen.contains('metadata.get("month"'))
	assert(start_screen.contains("CampaignManager.DEMO_FINAL_MONTH"))
	assert(start_screen.contains("CampaignManager.get_chapter_for_month(month)"))
	assert(start_screen.contains("TournamentManager.get_gt1_encounter(month)"))
	assert(start_screen.contains("_activity_name_for_month"))
	assert(not start_screen.contains("_battle_name_for_week"))
	assert(not start_screen.contains("_chapter_number_for_week"))
	assert(not start_screen.contains("week % 4"))
	assert(not start_screen.contains("week % 3"))
	assert(not start_screen.contains("week % 2"))

	assert(spanish.contains("Llegá al Mes XX y competí por Roma."))
	assert(spanish.contains('msgstr "{owner}\\nMes {week} de 20'))
	assert(spanish.contains('msgstr "Mes de gestión · Sin GT I"'))
	assert(spanish.contains('msgstr "Gran Torneo de Roma"'))
	assert(not spanish.contains("Sobreviví dieciséis semanas."))
	print("Start-screen monthly onboarding contract: OK")
