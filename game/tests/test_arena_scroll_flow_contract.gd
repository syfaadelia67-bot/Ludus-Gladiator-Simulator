extends SceneTree

func _initialize() -> void:
    var project := FileAccess.get_file_as_string("res://project.godot")
    var arena_scene_text := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")

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
        "Preparation",
        "StartCombat",
        "ResultSummary",
        "CombatLog",
        "BackToFinca"
    ]:
        assert(arena_scene_text.contains("name=\"%s\"" % required_node) or arena_scene_text.contains("name = \"%s\"" % required_node))

    assert(arena_scene_text.contains("combat_attack.png"))
    assert(arena_scene_text.contains("combat_defense.png"))
    assert(arena_scene_text.contains("combat_victory.png"))
    assert(arena_scene_text.contains("ScrollContainer"))

    assert(controller_text.contains("CombatManager.get_current_opponent_preview"))
    assert(controller_text.contains("CombatManager.configure_next_battle"))
    assert(controller_text.contains("CombatManager.simulate_duel"))
    assert(controller_text.contains("CombatManager.last_result"))
    assert(controller_text.contains("_restore_persistent_result"))
    assert(controller_text.contains("_start_replay"))
    assert(controller_text.contains("_return_to_finca"))
    assert(controller_text.contains("FincaHubController.open_system(\"equipamiento\")"))
    assert(controller_text.contains("FincaHubController.open_system(\"progresion\")"))
    assert(not controller_text.contains("grab_focus()"))

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
    assert(instance.get_node_or_null("Body/MainAndEncounter/CenterPanel") != null)
    assert(instance.get_node_or_null("Body/MainAndEncounter/EncounterPanel") != null)
    assert(instance.get_node_or_null("Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ActionRow/StartCombat") != null)
    assert(instance.get_node_or_null("Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ResultSummary") != null)
    instance.free()

    print("Arena dedicated screen contract: OK")
    quit()