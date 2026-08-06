extends SceneTree

func _initialize() -> void:
    var project := FileAccess.get_file_as_string("res://project.godot")
    var arena_scene_text := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var registry_text := FileAccess.get_file_as_string("res://scripts/ui/pack_000_asset_registry.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(project.contains("window/size/viewport_width=1920"))
    assert(project.contains("window/size/viewport_height=1080"))
    assert(project.contains("window/stretch/mode=\"canvas_items\""))
    assert(project.contains("window/stretch/aspect=\"expand\""))
    assert(project.contains("Pack000Assets=\"*res://scripts/ui/pack_000_asset_registry.gd\""))

    for required_node in ["RosterPanel", "CenterPanel", "EncounterPanel", "RosterList", "ArenaVisual", "Battlefield", "PlayerFighter", "EnemyFighter", "EffectIcon", "PreparationView", "ResultView", "StartCombat", "ViewResult", "BackToPreparation", "ResultSummary", "CombatLog", "BackToFinca"]:
        assert(arena_scene_text.contains("name=\"%s\"" % required_node) or arena_scene_text.contains("name = \"%s\"" % required_node))

    assert(arena_scene_text.contains("[node name=\"Body\" type=\"HBoxContainer\""))
    assert(not arena_scene_text.contains("HSplitContainer"))
    assert(arena_scene_text.count("type=\"ScrollContainer\"") == 3)
    assert(arena_scene_text.contains("Body/RosterPanel/Margin/Scroll"))
    assert(arena_scene_text.contains("Body/CenterPanel/Margin/Scroll"))
    assert(arena_scene_text.contains("Body/EncounterPanel/Margin/Scroll"))

    assert(controller_text.contains("_begin_live_animation"))
    assert(controller_text.contains("_play_next_live_action"))
    assert(controller_text.contains("_animate_action"))
    assert(controller_text.contains("create_tween()"))
    assert(controller_text.contains("CombatManager.simulate_duel"))
    assert(controller_text.contains("CombatManager.last_result"))
    assert(controller_text.contains("_restore_persistent_result"))
    assert(controller_text.contains("_settle_live_animation"))
    assert(controller_text.contains("FincaHubController.open_system(\"equipamiento\")"))
    assert(controller_text.contains("FincaHubController.open_system(\"progresion\")"))

    assert(registry_text.contains("_scan_directory(PACK_ROOT)"))
    assert(registry_text.contains("entry.to_lower().ends_with(\".png\")"))
    assert(registry_text.contains("textures[relative] = texture"))

    assert(hub_text.contains("\"arena\": \"res://scenes/ArenaScreen.tscn\""))
    assert(hub_text.contains("var packed := load(scene_path) as PackedScene"))
    assert(bootstrap_text.contains("FincaHubController.prepare_scene()"))
    assert(not bootstrap_text.contains("CombatManager."))
    assert(not bootstrap_text.contains("legacy_combat"))
    assert(not bootstrap_text.contains("_attach_arena_screen"))

    var arena_scene := load("res://scenes/ArenaScreen.tscn")
    var arena_script := load("res://scripts/ui/arena_screen.gd")
    var registry_script := load("res://scripts/ui/pack_000_asset_registry.gd")
    assert(arena_scene is PackedScene)
    assert(arena_script != null)
    assert(registry_script != null)

    var instance := (arena_scene as PackedScene).instantiate()
    assert(instance.get_node_or_null("Body/RosterPanel/Margin/Scroll") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Scroll") != null)
    assert(instance.get_node_or_null("Body/EncounterPanel/Margin/Scroll") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Scroll/Content/PreparationView/ArenaVisual/Margin/VisualContent/Battlefield/PlayerFighter") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Scroll/Content/PreparationView/ArenaVisual/Margin/VisualContent/Battlefield/EnemyFighter") != null)
    instance.free()

    print("Arena three-column scroll and routed live animation contract: OK")
    quit()
