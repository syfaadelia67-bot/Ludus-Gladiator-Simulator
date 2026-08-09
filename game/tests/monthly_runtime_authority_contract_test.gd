extends Node


func _ready() -> void:
	_assert_monthly_scheduler_authority()
	_assert_monthly_consumers()
	_assert_legacy_entrypoints_are_adapters()
	_assert_social_autoloads_use_monthly_wrappers()
	print("Monthly runtime authority contract: OK")
	get_tree().quit(0)


func _assert_monthly_scheduler_authority() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
	for call in [
		"RosterManager.process_month()",
		"RivalManager.process_month()",
		"EconomyManager.process_month()",
		"TournamentManager.process_month()",
		"EventManager.process_month()",
	]:
		assert(source.contains(call), "Canonical month closure must call %s" % call)
	for forbidden in [
		"RosterManager.process_day()",
		"RivalManager.process_week()",
		"EconomyManager.process_week()",
		"EventManager.process_week()",
		"range(DAYS_PER_WEEK)",
	]:
		assert(not source.contains(forbidden), "Month closure must not call %s" % forbidden)
	assert(source.contains("\"internal_work_ticks\": 1"))


func _assert_monthly_consumers() -> void:
	var market := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
	var planning := FileAccess.get_file_as_string(
		"res://scripts/systems/weekly_planning_controller.gd"
	)
	var cycle_ui := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_cycle_presentation.gd"
	)
	var closure_ui := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_closure_presenter.gd"
	)
	var calendar_ui := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_calendar_presenter.gd"
	)
	var event_ui := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_event_modal_presenter.gd"
	)

	assert(market.contains("GameState.month_advanced.connect"))
	assert(not market.contains("GameState.week_advanced.connect"))
	assert(planning.contains("EconomyManager.get_monthly_projection()"))
	assert(planning.contains("\"month\": GameState.get_month()"))
	assert(not planning.contains("GameState.DAYS_PER_WEEK"))
	assert(cycle_ui.contains("GameState.month_advanced.connect"))
	assert(closure_ui.contains("GameState.advance_month()"))
	assert(calendar_ui.contains("GameState.month_advanced.connect"))
	assert(calendar_ui.contains("DEMO_FINAL_MONTH := 20"))
	assert(event_ui.contains("EVENTO MENSUAL · MES"))


func _assert_legacy_entrypoints_are_adapters() -> void:
	var roster := FileAccess.get_file_as_string("res://scripts/systems/roster_manager.gd")
	var rivals := FileAccess.get_file_as_string("res://scripts/systems/rival_manager_weekly.gd")
	var economy := FileAccess.get_file_as_string("res://scripts/systems/economy_manager_weekly.gd")
	var tournaments := FileAccess.get_file_as_string(
		"res://scripts/systems/tournament_manager_weekly.gd"
	)
	var events := FileAccess.get_file_as_string("res://scripts/systems/event_manager_demo.gd")

	assert(roster.contains("func process_day()"))
	assert(roster.contains("return process_month()"))
	assert(rivals.contains("func process_week()"))
	assert(rivals.contains("func process_day()"))
	assert(rivals.count("return process_month()") >= 2)
	assert(economy.contains("func process_week()"))
	assert(economy.contains("return process_month()"))
	assert(tournaments.contains("func process_week()"))
	assert(tournaments.contains("func process_day()"))
	assert(tournaments.count("return process_month()") >= 2)
	assert(events.contains("func process_week()"))
	assert(events.contains("func process_day()"))
	assert(events.count("return process_month()") >= 2)


func _assert_social_autoloads_use_monthly_wrappers() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert(
		project.contains(
			"PersonalityManager=\"*res://scripts/systems/personality_manager_monthly.gd\""
		)
	)
	assert(
		project.contains(
			"RelationshipManager=\"*res://scripts/systems/relationship_manager_monthly.gd\""
		)
	)
