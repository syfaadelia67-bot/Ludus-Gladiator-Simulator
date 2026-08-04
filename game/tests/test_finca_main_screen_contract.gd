extends SceneTree

func _initialize() -> void:
    var scene_text := FileAccess.get_file_as_string("res://scenes/FincaScreen.tscn")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var shell_scene_text := FileAccess.get_file_as_string("res://scenes/UnifiedHudShell.tscn")
    var shell_controller_text := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")

    for required_node in ["TopHUD", "MainNavigation", "WorldArea", "BuildingDetailsPanel", "BottomStatusBar"]:
        assert(scene_text.contains("name=\"%s\"" % required_node) or scene_text.contains("name = \"%s\"" % required_node))

    for building_id in [
        "dominus_house",
        "barracks",
        "training_yard",
        "forge",
        "infirmary",
        "kitchen",
        "warehouse",
        "worker_quarters",
        "wall_and_gate",
        "beast_area",
        "sanctuary",
        "private_arena",
        "stable"
    ]:
        assert(controller_text.contains("\"%s\"" % building_id))

    assert(controller_text.contains("const BUILDING_LAYOUT"))
    assert(controller_text.contains("_build_hotspots()"))
    assert(controller_text.contains("EventManager.get_pending_event()"))
    assert(controller_text.contains("CombatManager.get_current_event_details()"))
    assert(controller_text.contains("EstateManager.can_upgrade"))

    assert(bootstrap_text.contains("preload(\"res://scenes/FincaScreen.tscn\")"))
    assert(bootstrap_text.contains("preload(\"res://scenes/UnifiedHudShell.tscn\")"))
    assert(bootstrap_text.contains("_attach_finca_screen(tabs)"))
    assert(bootstrap_text.contains("_attach_unified_hud(root)"))
    assert(bootstrap_text.contains("main_tabs.tabs_visible = false"))
    assert(bootstrap_text.contains("_disable_embedded_finca_shell"))
    assert(not bootstrap_text.contains("control.visible = not active"))

    for required_shell_node in ["TopHUD", "MainNavigation", "BottomStatusBar", "More", "Section"]:
        assert(shell_scene_text.contains("name=\"%s\"" % required_shell_node) or shell_scene_text.contains("name = \"%s\"" % required_shell_node))
    assert(shell_controller_text.contains("const PRIMARY_SYSTEMS"))
    assert(shell_controller_text.contains("const MORE_SYSTEMS"))
    assert(shell_controller_text.contains("FincaHubController.system_opened.connect"))
    assert(shell_controller_text.contains("_refresh_navigation"))

    for mapping in [
        "\"relaciones\": \"Relaciones\"",
        "\"personalidad\": \"Personalidad\"",
        "\"transferencias\": \"Transferencias\"",
        "\"historial\": \"Historial\"",
        "\"infirmary\": \"personal\"",
        "\"kitchen\": \"economia\""
    ]:
        assert(hub_text.contains(mapping))
    assert(hub_text.contains("EstateManager.is_locked(canonical_id)"))

    var finca_scene := load("res://scenes/FincaScreen.tscn")
    var finca_script := load("res://scripts/ui/finca_screen.gd")
    var shell_scene := load("res://scenes/UnifiedHudShell.tscn")
    var shell_script := load("res://scripts/ui/unified_hud_shell.gd")
    assert(finca_scene is PackedScene)
    assert(finca_script != null)
    assert(shell_scene is PackedScene)
    assert(shell_script != null)

    var finca_instance := (finca_scene as PackedScene).instantiate()
    assert(finca_instance.get_node_or_null("Center/WorldPanel/WorldMargin/WorldArea") != null)
    assert(finca_instance.get_node_or_null("Center/BuildingDetailsPanel") != null)
    finca_instance.free()

    var shell_instance := (shell_scene as PackedScene).instantiate()
    assert(shell_instance.get_node_or_null("TopHUD") != null)
    assert(shell_instance.get_node_or_null("MainNavigation") != null)
    assert(shell_instance.get_node_or_null("BottomStatusBar") != null)
    shell_instance.free()

    print("Finca main screen and unified HUD contract: OK")
    quit()
