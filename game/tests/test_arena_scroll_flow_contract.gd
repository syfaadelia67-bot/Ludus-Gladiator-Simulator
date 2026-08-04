extends SceneTree

func _initialize() -> void:
    var project := FileAccess.get_file_as_string("res://project.godot")
    var arena_scene_text := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")

    assert(project.contains("window/size/viewport_width=1920"))
    assert(project.contains("window/size/viewport_height=1080"))
    assert(project.contains("window/stretch/mode=\"canvas_items\""))
    assert(project.contains("window/stretch/aspect=\"expand\""))

    assert(not project.contains("ArenaCombatResultPresenter="))
    assert(not project.contains("ArenaOpponentPreviewPresenter="))
    assert(not project.contains("ArenaFinaleWarningPresenter="))
    assert(not project.contains("PlaceholderAssetIntegrator="))

    for required_node in [
        "RosterPanel",
        "CenterPanel",
        "EncounterPanel",
        "RosterList",
        "ArenaVisual",
        "PreparationView",
        "ResultView",
        "StartCombat",
        "ViewResult",
        "BackToPreparation",
        "ResultSummary",
        "CombatLog",
        "BackToFinca"
    ]:
        assert(arena_scene_text.contains("name=\"%s\"" % required_node) or arena_scene_text.contains("name = \"%s\"" % required_node))

    assert(arena_scene_text.contains("[node name=\"Body\" type=\"HBoxContainer\""))
    assert(not arena_scene_text.contains("HSplitContainer"))
    assert(not arena_scene_text.contains("Body/CenterPanel/Margin/Scroll"))
    assert(arena_scene_text.contains("custom_minimum_size = Vector2(320, 0)"))
    assert(arena_scene_text.contains("custom_minimum_size = Vector2(820, 0)"))
    assert(arena_scene_text.contains("custom_minimum_size = Vector2(340, 0)"))
    assert(arena_scene_text.contains("size_flags_stretch_ratio = 0.24"))
    assert(arena_scene_text.contains("size_flags_stretch_ratio = 0.52"))
    assert(arena_scene_text.contains("custom_minimum_size = Vector2(0, 410)"))
    assert(arena_scene_text.contains("custom_minimum_size = Vector2(420, 58)"))
    assert(arena_scene_text.contains("combat_attack.png"))
    assert(arena_scene_text.contains("combat_defense.png"))
    assert(arena_scene_text.contains("combat_victory.png"))

    assert(controller_text.contains("CombatManager.get_current_opponent_preview"))
    assert(controller_text.contains("CombatManager.configure_next_battle"))
    assert(controller_text.contains("CombatManager.simulate_duel"))
    assert(controller_text.contains("CombatManager.last_result"))
    assert(controller_text.contains("_restore_persistent_result"))
    assert(controller_text.contains("_show_preparation_view"))
    assert(controller_text.contains("_show_result_view"))
    assert(controller_text.contains("preparation_view.visible = false"))
    assert(controller_text.contains("result_view.visible = true"))
    assert(controller_text.contains("_start_replay"))
    assert(controller_text.contains("_return_to_finca"))
    assert(controller_text.contains("FincaHubController.open_system(\"equipamiento\")"))
    assert(controller_text.contains("FincaHubController.open_system(\"progresion\")"))
    assert(not controller_text.contains("grab_focus()"))
    assert(not controller_text.contains("center_scroll"))

    assert(bootstrap_text.contains("preload(\"res://scenes/ArenaScreen.tscn\")"))
    assert(bootstrap_text.contains("_attach_arena_screen(tabs)"))
    assert(bootstrap_text.contains("primary_arena_screen"))
    assert(bootstrap_text.contains("CombatManager.combat_finished.disconnect"))
    assert(not bootstrap_text.contains("ARENA_CONTROLLER"))
    assert(not bootstrap_text.contains("_repair_arena_navigation"))

    var arena_scene := load("res://scenes/ArenaScreen.tscn")
    var arena_script := load("res://scripts/ui/arena_screen.gd")
    assert(arena_scene is PackedScene)
    assert(arena_script != null)

    var instance := (arena_scene as PackedScene).instantiate()
    assert(instance.get_node_or_null("Body/RosterPanel") != null)
    assert(instance.get_node_or_null("Body/CenterPanel") != null)
    assert(instance.get_node_or_null("Body/EncounterPanel") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Content/PreparationView/ActionRow/StartCombat") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Content/ResultView/ResultSummary") != null)
    assert(instance.get_node_or_null("Body/CenterPanel/Margin/Content/TopBar/BackToFinca") != null)
    instance.free()

    print("Arena Full HD layout contract: OK")
    quit()
