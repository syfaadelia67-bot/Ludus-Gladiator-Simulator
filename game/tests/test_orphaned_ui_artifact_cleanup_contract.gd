extends Node

const REMOVED_UI_ARTIFACTS := [
	"res://scripts/ui/arena_opponent_preview_presenter.gd",
	"res://scripts/ui/arena_finale_warning_presenter.gd",
	"res://scripts/ui/placeholder_asset_integrator.gd",
]


func run() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var arena := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
	var equipment_scene := FileAccess.get_file_as_string("res://scenes/EquipmentScreen.tscn")

	for artifact_path in REMOVED_UI_ARTIFACTS:
		assert(not FileAccess.file_exists(artifact_path))
		assert(not project.contains(artifact_path.get_file()))

	assert(not project.contains("ArenaOpponentPreviewPresenter="))
	assert(not project.contains("ArenaFinaleWarningPresenter="))
	assert(not project.contains("PlaceholderAssetIntegrator="))

	assert(arena.contains("CombatV1ArenaRuntimeScript"))
	assert(arena.contains("_refresh_encounter_panel"))
	assert(arena.contains("snapshot canónico explícito"))
	assert(arena.contains("GameState.get_month()"))
	assert(not arena.contains("CombatManager"))
	assert(not arena.contains("FINAL_WEEK"))
	assert(not arena.contains("Margin/VBox/Tabs/Arena"))

	assert(FileAccess.file_exists("res://scripts/ui/equipment_panel.gd"))
	assert(FileAccess.file_exists("res://scripts/ui/equipment_panel_v1.gd"))
	assert(equipment_scene.contains("res://scripts/ui/equipment_panel_v1.gd"))
	assert(not equipment_scene.contains("res://scripts/ui/equipment_panel.gd"))

	print("Orphaned UI artifact and legacy Arena authority cleanup contract: OK")
