extends Node

const REMOVED_UI_ARTIFACTS := [
    "res://scripts/ui/arena_opponent_preview_presenter.gd",
    "res://scripts/ui/arena_finale_warning_presenter.gd",
    "res://scripts/ui/placeholder_asset_integrator.gd"
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

    assert(arena.contains("func _refresh_encounter()"))
    assert(arena.contains("CombatManager.get_current_opponent_preview(selected_fighter_id)"))
    assert(arena.contains("const FINAL_WEEK := 16"))
    assert(arena.contains("COMBATE FINAL DE LA DEMO"))
    assert(arena.contains("Pack000Assets"))
    assert(not arena.contains("Margin/VBox/Tabs/Arena"))

    assert(FileAccess.file_exists("res://scripts/ui/equipment_panel.gd"))
    assert(equipment_scene.contains('res://scripts/ui/equipment_panel.gd'))

    print("Orphaned UI artifact cleanup contract: OK")
