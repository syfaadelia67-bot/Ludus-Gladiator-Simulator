extends Node

const PANEL_SCRIPT := "res://scripts/ui/gt1_series_setup_panel.gd"
const PANEL_SCENE := "res://scenes/GT1SeriesSetupPanel.tscn"
const ARENA_SCRIPT := "res://scripts/ui/arena_screen.gd"


func run() -> void:
	var panel := FileAccess.get_file_as_string(PANEL_SCRIPT)
	var scene := FileAccess.get_file_as_string(PANEL_SCENE)
	var arena := FileAccess.get_file_as_string(ARENA_SCRIPT)
	assert(not panel.is_empty())
	assert(not scene.is_empty())
	assert(not arena.is_empty())

	assert(panel.contains("start_month_13_catalog_session"))
	assert(panel.contains("start_month_16_catalog_human_session"))
	assert(panel.contains("start_month_16_beast_session"))
	assert(panel.contains("start_month_20_catalog_session"))
	assert(panel.contains("DataRepository.rival_combat_v1_snapshots"))
	assert(panel.contains("DataRepository.beasts"))
	assert(panel.contains('"explicit_selection_required": true'))
	assert(panel.contains('"generated_opponents_allowed": false'))
	assert(panel.contains("PLAYER_TEAM_ID"))
	assert(panel.contains("BEAST_TEAM_ID"))
	assert(not panel.contains("CombatManager"))
	assert(not panel.contains("RivalManager"))
	assert(not panel.contains("rand"))

	assert(scene.contains('name="RivalLudusSelector"'))
	assert(scene.contains('name="OpponentModeSelector"'))
	assert(scene.contains('name="Player6Selector"'))
	assert(scene.contains('name="Opponent6Selector"'))
	assert(scene.contains('name="BeginSeries"'))

	assert(arena.contains("GT1SeriesSetupPanelScene"))
	assert(arena.contains("_install_series_setup_panel"))
	assert(arena.contains("_on_series_setup_session_started"))
	assert(arena.contains('"opponent_selection_is_external": false'))
	assert(arena.contains('"explicit_series_selection_required": true'))
	assert(arena.contains('"generated_opponents_allowed": false'))
	print("GT I player-facing series setup panel contract: OK")
