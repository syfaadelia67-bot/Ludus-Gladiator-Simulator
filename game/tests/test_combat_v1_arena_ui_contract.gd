extends Node

const ARENA_PATH := "res://scripts/ui/arena_screen.gd"
const PRESENTATION_GUARD_PATH := "res://scripts/ui/arena_tournament_presentation_guard.gd"
const SETUP_PANEL_PATH := "res://scripts/ui/gt1_series_setup_panel.gd"
const SETUP_RUNTIME_PATH := "res://scripts/ui/gt1_series_setup_runtime.gd"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(ARENA_PATH)
	var presentation_guard := FileAccess.get_file_as_string(PRESENTATION_GUARD_PATH)
	var setup_panel := FileAccess.get_file_as_string(SETUP_PANEL_PATH)
	var setup_runtime := FileAccess.get_file_as_string(SETUP_RUNTIME_PATH)
	assert(not source.is_empty(), "ArenaScreen source must be readable")
	assert(not presentation_guard.is_empty(), "Final Arena presentation guard must be readable")
	assert(not setup_panel.is_empty(), "GT I series setup panel source must be readable")
	assert(not setup_runtime.is_empty(), "GT I series setup runtime source must be readable")
	assert(source.contains("CombatV1ArenaRuntimeScript"))
	assert(source.contains("GT1SeriesSetupPanelScene"))
	assert(source.contains('"opponent_selection_is_external": false'))
	assert(source.contains('"explicit_series_selection_required": true'))
	assert(setup_panel.contains("GT1SeriesSetupRuntimeScript"))
	assert(setup_panel.contains("get_gt1_setup_catalog"))
	assert(setup_panel.contains("start_month_13_session"))
	assert(setup_panel.contains("start_month_16_human_session"))
	assert(setup_panel.contains("start_month_16_beast_session"))
	assert(setup_panel.contains("start_month_20_session"))
	assert(setup_runtime.contains("DataRepository.rival_combat_v1_snapshots"))
	assert(setup_runtime.contains("DataRepository.beasts"))
	assert(setup_runtime.contains('"generated_opponents_allowed": false'))
	assert(source.contains("GameState.month_advanced"))
	assert(source.contains("FUE"))
	assert(source.contains("AGI"))
	assert(source.contains("TEC"))
	assert(source.contains("RES"))
	assert(source.contains("PV"))
	assert(source.contains("Stamina"))
	assert(presentation_guard.contains("_resolve_current_autobattle"))
	assert(presentation_guard.contains('"manual_midfight_input_disabled"'))
	assert(presentation_guard.contains("func _focus_running_combat_controls() -> void:"))
	assert(presentation_guard.contains("action_selector.visible = false"))
	assert(presentation_guard.contains("target_selector.visible = false"))
	assert(presentation_guard.contains("start_button.visible = false"))
	assert(presentation_guard.contains("El combate se resuelve automáticamente."))
	assert(not source.contains("CombatManager"))
	assert(not setup_panel.contains("CombatManager"))
	assert(not setup_runtime.contains("CombatManager"))
	assert(not setup_panel.contains("RivalManager"))
	assert(not setup_runtime.contains("RivalManager"))
	assert(not source.contains("week_advanced"))
	assert(not source.contains("get_week()"))
	assert(not source.contains(".endurance"))
	assert(not source.contains("GladiatorProgressionManager.abilities"))
	assert(not source.contains("simulate_duel"))
	print("Combat V1 Arena UI authority contract: OK")
	get_tree().quit(0)
