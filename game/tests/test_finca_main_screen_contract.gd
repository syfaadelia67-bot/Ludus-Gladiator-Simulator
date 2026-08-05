extends SceneTree

func _initialize() -> void:
    var scene_text := FileAccess.get_file_as_string("res://scenes/FincaScreen.tscn")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var shell_scene_text := FileAccess.get_file_as_string("res://scenes/UnifiedHudShell.tscn")
    var shell_controller_text := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")

    for required_node in ["TopHUD", "MainNavigation", "WorldArea", "BuildingDetailsPanel", "Scroll", "BottomStatusBar"]:
        assert(scene_text.contains("name=\"%s\"" % required_node) or scene_text.contains("name = \"%s\"" % required_node))

    for building_id in ["dominus_house", "barracks", "training_yard", "forge", "infirmary", "kitchen", "warehouse", "worker_quarters", "wall_and_gate", "beast_area", "sanctuary", "private_arena", "stable"]:
        assert(controller_text.contains("\"%s\"" % building_id))

    assert(controller_text.contains("const BUILDING_LAYOUT"))
    assert(controller_text.contains("const HOTSPOT_NAMES"))
    assert(controller_text.contains("_build_hotspots()"))
    assert(controller_text.contains("EstateManager.can_upgrade"))

    assert(bootstrap_text.contains("FincaHubController.prepare_scene()"))
    assert(bootstrap_text.contains("FincaHubController.show_finca()"))
    assert(bootstrap_text.contains("main_tabs.visible = false"))
    assert(not bootstrap_text.contains("_attach_finca_screen"))
    assert(not bootstrap_text.contains("_select_finca_as_primary_view"))

    assert(hub_text.contains("const SCREEN_HOST_NAME := \"ScreenHost\""))
    assert(hub_text.contains("\"finca\": \"res://scenes/FincaScreen.tscn\""))
    assert(hub_text.contains("var packed := load(scene_path) as PackedScene"))
    assert(hub_text.contains("func _show_hosted_screen"))
    assert(hub_text.contains("func _show_legacy_screen"))
    assert(hub_text.contains("return current_system_id"))

    for required_shell_node in ["TopHUD", "MainNavigation", "BottomStatusBar", "More", "Section", "Barracks"]:
        assert(shell_scene_text.contains("name=\"%s\"" % required_shell_node) or shell_scene_text.contains("name = \"%s\"" % required_shell_node))
    assert(shell_scene_text.contains("anchor_left = 1.0"))
    assert(shell_scene_text.contains("corner_radius_top_left = 30"))
    assert(shell_scene_text.contains("MainNavigation/Margin/Column"))
    assert(shell_controller_text.contains("$MainNavigation/Margin/Column/Finca"))
    assert(shell_controller_text.contains("FincaHubController.open_system"))

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
    assert(finca_instance.get_node_or_null("Center/BuildingDetailsPanel/Margin/Scroll") is ScrollContainer)
    finca_instance.free()

    var shell_instance := (shell_scene as PackedScene).instantiate()
    assert(shell_instance.get_node_or_null("TopHUD") != null)
    assert(shell_instance.get_node_or_null("MainNavigation/Margin/Column/Finca") is Button)
    assert(shell_instance.get_node_or_null("MainNavigation/Margin/Column/More") is MenuButton)
    assert(shell_instance.get_node_or_null("BottomStatusBar") != null)
    shell_instance.free()

    print("Finca central ScreenHost and circular HUD contract: OK")
    quit()
