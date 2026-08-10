extends Node


func run() -> void:
	assert(TournamentManager.is_grand_tournament_month(13))
	assert(TournamentManager.is_grand_tournament_month(16))
	assert(TournamentManager.is_grand_tournament_month(20))
	assert(not TournamentManager.is_grand_tournament_month(12))
	assert(not TournamentManager.is_grand_tournament_month(19))

	var month_13 := TournamentManager.get_gt1_encounter(13)
	var month_16 := TournamentManager.get_gt1_encounter(16)
	var month_20 := TournamentManager.get_gt1_encounter(20)
	assert(str(month_13.get("format", "")) == "1v1")
	assert(str(month_16.get("format", "")) == "1v1")
	assert(str(month_20.get("format", "")) == "2v2")
	assert(int(month_13.get("bouts", 0)) == 3)
	assert(int(month_16.get("bouts", 0)) == 3)
	assert(int(month_20.get("bouts", 0)) == 3)

	var calendar_source := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_calendar_presenter.gd"
	)
	assert(calendar_source.contains("DEMO_FINAL_MONTH := 20"))
	assert(calendar_source.contains("GameState.month_advanced.connect"))
	assert(calendar_source.contains("TournamentManager.is_grand_tournament_month(month)"))
	assert(calendar_source.contains("TournamentManager.get_gt1_encounter(month)"))
	assert(calendar_source.contains("CALENDARIO MENSUAL"))
	assert(not calendar_source.contains("DEMO_FINAL_WEEK"))
	assert(not calendar_source.contains("CombatManager.get_event_details_for_week"))

	var game_state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	assert(game_state_source.contains("TournamentManager.get_gt1_encounter(get_month())"))
	assert(not game_state_source.contains("CombatManager.get_current_event_details()"))

	print("Monthly campaign calendar and GT I contract: OK")
