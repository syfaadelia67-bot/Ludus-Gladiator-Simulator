extends Node

var _captured_month: int = -1
var _captured_report: Dictionary = {}


func _ready() -> void:
	GameState.month_advanced.connect(_on_month_advanced)
	GameState.monthly_report.connect(_on_monthly_report)

	_test_month_aliases()
	_test_single_month_tick()
	_test_save_v14_month_aliases()
	_test_legacy_v14_week_loads_as_month()
	_test_demo_calendar_uses_month_xx()

	print("Monthly campaign foundation tests passed")
	get_tree().quit(0)


func _test_month_aliases() -> void:
	GameState.day = 7
	assert(GameState.get_month() == 7, "Canonical campaign turn must be month 7")
	assert(GameState.get_week() == 7, "Legacy week alias must map 1:1 to month")


func _test_single_month_tick() -> void:
	GameState.day = 1
	CampaignManager.campaign_over = false
	_captured_month = -1
	_captured_report = {}

	GameState.advance_month()

	assert(GameState.get_month() == 2, "Closing month I must advance the campaign to month II")
	assert(_captured_month == 2, "month_advanced must emit the new campaign month")
	assert(not _captured_report.is_empty(), "Monthly closure must emit a report")
	assert(_captured_report.get("period", "") == "month", "Report period must be month")
	assert(int(_captured_report.get("closed_month", 0)) == 1, "Report must identify month I")
	assert(int(_captured_report.get("next_month", 0)) == 2, "Report must identify month II")
	assert(
		int(_captured_report.get("internal_work_ticks", 0)) == 1,
		"Monthly closure must not simulate seven internal weekly/daily ticks"
	)
	assert(
		_captured_report.get("work_results", []).size() == 1,
		"Roster work must resolve exactly once per campaign month"
	)


func _test_save_v14_month_aliases() -> void:
	var payload: Dictionary = SaveManager._build_payload()
	assert(int(payload.get("version", 0)) == 14, "Monthly migration must keep SAVE_VERSION 14")
	var game_data: Dictionary = payload.get("game_state", {})
	var month := GameState.get_month()
	assert(int(game_data.get("month", 0)) == month, "New v14 saves must persist month")
	assert(int(game_data.get("week", 0)) == month, "v14 week alias must mirror month")
	assert(int(game_data.get("day", 0)) == month, "v14 day alias must mirror month")


func _test_legacy_v14_week_loads_as_month() -> void:
	var legacy_payload: Dictionary = SaveManager._build_payload()
	var legacy_game_data: Dictionary = legacy_payload.get("game_state", {}).duplicate(true)
	legacy_game_data.erase("month")
	legacy_game_data["week"] = 9
	legacy_game_data["day"] = 9
	legacy_payload["game_state"] = legacy_game_data

	GameState.day = 1
	assert(SaveManager._apply_payload(legacy_payload), "Legacy v14 payload must still load")
	assert(GameState.get_month() == 9, "Legacy week 9 must migrate 1:1 to month IX")


func _test_demo_calendar_uses_month_xx() -> void:
	assert(CampaignManager.DEMO_FINAL_MONTH == 20, "Demo must end in month XX")
	assert(CampaignManager.DEMO_FINAL_WEEK == 20, "Legacy final-week alias must mirror month XX")
	var final_chapter: Dictionary = CampaignManager.get_chapter_for_month(13)
	assert(
		int(final_chapter.get("month_start", 0)) == 13,
		"Final demo chapter must begin in month XIII"
	)
	assert(int(final_chapter.get("month_end", 0)) == 20, "Final demo chapter must end in month XX")


func _on_month_advanced(month: int) -> void:
	_captured_month = month


func _on_monthly_report(report: Dictionary) -> void:
	_captured_report = report.duplicate(true)
