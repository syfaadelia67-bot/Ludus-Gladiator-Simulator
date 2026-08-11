extends Node

const ARENA_PATH := "res://scripts/ui/arena_screen.gd"
const SETUP_PATH := "res://scripts/ui/gt1_series_setup_panel.gd"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(ARENA_PATH)
	var setup := FileAccess.get_file_as_string(SETUP_PATH)
	assert(not source.is_empty(), "ArenaScreen source must be readable")
	assert(not setup.is_empty(), "GT I series setup source must be readable")
	assert(
		source.contains("CombatV1ArenaRuntimeScript"),
		"ArenaScreen must use the Combat V1 runtime bridge"
	)
	assert(source.contains("GT1SeriesSetupPanelScene"))
	assert(source.contains("DataRepository.rival_combat_v1_snapshots"))
	assert(source.contains("DataRepository.beasts"))
	assert(source.contains('"opponent_selection_is_external": false'))
	assert(source.contains('"explicit_series_selection_required": true'))
	assert(setup.contains("get_gt1_setup_catalog"))
	assert(setup.contains("start_month_13_catalog_session"))
	assert(setup.contains("start_month_16_catalog_human_session"))
	assert(setup.contains("start_month_16_beast_session"))
	assert(setup.contains("start_month_20_catalog_session"))
	assert(setup.contains('"generated_opponents_allowed": false'))
	assert(
		source.contains("GameState.month_advanced"),
		"ArenaScreen must follow canonical monthly time"
	)
	assert(source.contains("FUE"))
	assert(source.contains("AGI"))
	assert(source.contains("TEC"))
	assert(source.contains("RES"))
	assert(source.contains("PV"))
	assert(source.contains("Stamina"))
	assert(
		not source.contains("CombatManager"),
		"ArenaScreen must not call the quarantined legacy combat manager"
	)
	assert(not setup.contains("CombatManager"))
	assert(not setup.contains("RivalManager"))
	assert(
		not source.contains("week_advanced"), "ArenaScreen must not subscribe to weekly scheduling"
	)
	assert(
		not source.contains("get_week()"), "ArenaScreen must not present weekly campaign authority"
	)
	assert(
		not source.contains(".endurance"),
		"ArenaScreen must not use legacy endurance as Combat V1 RES"
	)
	assert(
		not source.contains("GladiatorProgressionManager.abilities"),
		"ArenaScreen must not expose legacy ability plans"
	)
	assert(
		not source.contains("simulate_duel"),
		"ArenaScreen must not resolve combat through a legacy duel API"
	)
	print("Combat V1 Arena UI authority contract: OK")
	get_tree().quit(0)
