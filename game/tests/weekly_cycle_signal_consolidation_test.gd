extends Node


func run() -> void:
	var save_source := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")
	var economy_source := FileAccess.get_file_as_string(
		"res://scripts/systems/economy_manager_weekly.gd"
	)
	var state_source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")

	assert(save_source.contains("GameState.month_advanced"))
	assert(save_source.contains("_on_month_advanced"))
	assert(not save_source.contains("GameState.day_advanced.connect"))
	assert(not save_source.contains("GameState.week_advanced.connect"))

	# Economy still exposes its legacy weekly method name during migration, but it
	# is invoked exactly once by the canonical monthly closure.
	assert(economy_source.contains("signal weekly_economy_processed"))
	assert(economy_source.contains("func process_week()"))
	assert(economy_source.contains("super.process_day()"))

	assert(state_source.contains("signal month_advanced(month: int)"))
	assert(state_source.contains("signal monthly_report(report: Dictionary)"))
	assert(state_source.contains("func advance_month()"))
	assert(state_source.contains("EconomyManager.process_week()"))
	assert(state_source.contains("func advance_week()"))
	assert(state_source.contains("advance_month()"))
	assert(state_source.contains("week_advanced.emit(get_week())"))
	assert(state_source.contains("day_advanced.emit(day)"))
	assert(state_source.contains("daily_report.emit(report)"))

	print("PASS: canonical monthly autosave with legacy cycle aliases")
