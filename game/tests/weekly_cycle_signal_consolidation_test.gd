extends Node


func run() -> void:
	var save_source := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")
	var economy_source := FileAccess.get_file_as_string(
		"res://scripts/systems/economy_manager_weekly.gd"
	)
	var state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	var roster_source := FileAccess.get_file_as_string("res://scripts/systems/roster_manager.gd")
	var market_source := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")

	assert(save_source.contains("GameState.month_advanced"))
	assert(save_source.contains("_on_month_advanced"))
	assert(not save_source.contains("GameState.day_advanced.connect"))
	assert(not save_source.contains("GameState.week_advanced.connect"))

	assert(economy_source.contains("signal monthly_economy_processed"))
	assert(economy_source.contains("func process_month()"))
	assert(economy_source.contains("func process_week()"))
	assert(economy_source.contains("return process_month()"))

	assert(roster_source.contains("signal monthly_results"))
	assert(roster_source.contains("func process_month()"))
	assert(roster_source.contains("func process_day()"))
	assert(roster_source.contains("return process_month()"))

	assert(state_source.contains("signal month_advanced(month: int)"))
	assert(state_source.contains("signal monthly_report(report: Dictionary)"))
	assert(state_source.contains("func advance_month()"))
	assert(state_source.contains("RosterManager.process_month()"))
	assert(state_source.contains("RivalManager.process_month()"))
	assert(state_source.contains("EconomyManager.process_month()"))
	assert(state_source.contains("TournamentManager.process_month()"))
	assert(state_source.contains("EventManager.process_month()"))
	assert(not state_source.contains("RosterManager.process_day()"))
	assert(not state_source.contains("RivalManager.process_week()"))
	assert(not state_source.contains("EconomyManager.process_week()"))
	assert(not state_source.contains("EventManager.process_week()"))
	assert(state_source.contains("\"internal_work_ticks\": 1"))
	assert(not state_source.contains("range(DAYS_PER_WEEK)"))

	# Save-v14 compatibility aliases remain available but cannot schedule runtime.
	assert(state_source.contains("func advance_week()"))
	assert(state_source.contains("func advance_day()"))
	assert(state_source.contains("week_advanced.emit(get_month())"))
	assert(state_source.contains("day_advanced.emit(day)"))
	assert(state_source.contains("daily_report.emit(report)"))

	assert(market_source.contains("GameState.month_advanced.connect"))
	assert(not market_source.contains("GameState.week_advanced.connect"))

	print("PASS: canonical monthly runtime with legacy cycle aliases only")
