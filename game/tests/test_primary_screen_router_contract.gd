extends SceneTree

func _initialize() -> void:
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var shell_scene_text := FileAccess.get_file_as_string("res://scenes/UnifiedHudShell.tscn")
    var shell_script_text := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")
    var market_scene_text := FileAccess.get_file_as_string("res://scenes/MarketScreen.tscn")
    var market_script_text := FileAccess.get_file_as_string("res://scripts/ui/market_screen.gd")
    var barracks_scene_text := FileAccess.get_file_as_string("res://scenes/BarracksScreen.tscn")
    var barracks_script_text := FileAccess.get_file_as_string("res://scripts/ui/barracks_screen.gd")
    var save_text := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")

    assert(hub_text.contains("const SCREEN_HOST_NAME := \"ScreenHost\""))
    assert(hub_text.contains("func prepare_scene()"))
    assert(hub_text.contains("func _show_hosted_screen"))
    assert(hub_text.contains("func _show_legacy_screen"))
    assert(hub_text.contains("var current_system_id := \"finca\""))
    assert(hub_text.contains("host.visible = true"))
    assert(hub_text.contains("tabs.visible = false"))
    assert(hub_text.contains("var packed := load(scene_path) as PackedScene"))

    for routed_scene in [
        "FincaScreen.tscn", "BarracksScreen.tscn", "MarketScreen.tscn", "ArenaScreen.tscn",
        "CampaignPanel.tscn", "RelationshipsPanel.tscn", "RivalsPanel.tscn"
    ]:
        assert(hub_text.contains(routed_scene))

    assert(bootstrap_text.contains("FincaHubController.prepare_scene()"))
    assert(bootstrap_text.contains("FincaHubController.show_finca()"))
    assert(bootstrap_text.contains("main_tabs.visible = false"))
    assert(not bootstrap_text.contains("func _unhandled_key_input"))
    assert(not bootstrap_text.contains("_attach_panels"))
    assert(not bootstrap_text.contains("_attach_finca_screen"))
    assert(not bootstrap_text.contains("_attach_market_screen"))
    assert(not bootstrap_text.contains("_attach_arena_screen"))

    assert(shell_scene_text.contains("anchor_left = 1.0"))
    assert(shell_scene_text.contains("corner_radius_top_left = 30"))
    assert(shell_scene_text.contains("MainNavigation/Margin/Column"))
    assert(shell_script_text.contains("$MainNavigation/Margin/Column/Finca"))
    assert(shell_script_text.contains("$MainNavigation/Margin/Column/Barracks"))
    assert(shell_script_text.contains("$MainNavigation/Margin/Column/Mercado"))

    assert(not market_scene_text.contains("TabContainer"))
    assert(not barracks_scene_text.contains("TabContainer"))
    assert(market_scene_text.contains("name=\"FightersCard\" type=\"TextureButton\""))
    assert(market_scene_text.contains("name=\"EquipmentCard\" type=\"TextureButton\""))
    assert(barracks_scene_text.contains("name=\"PersonalCard\" type=\"TextureButton\""))
    assert(barracks_scene_text.contains("name=\"FightersCard\" type=\"TextureButton\""))
    assert(market_script_text.contains("const COVER_CARD_SIZE := Vector2(850, 478)"))
    assert(barracks_script_text.contains("const COVER_CARD_SIZE := Vector2(850, 478)"))

    assert(save_text.contains("const SAVE_VERSION := 14"))

    var market_scene := load("res://scenes/MarketScreen.tscn")
    var barracks_scene := load("res://scenes/BarracksScreen.tscn")
    var hud_scene := load("res://scenes/UnifiedHudShell.tscn")
    assert(market_scene is PackedScene)
    assert(barracks_scene is PackedScene)
    assert(hud_scene is PackedScene)

    print("Primary ScreenHost, circular HUD and 16:9 cover navigation contract: OK")
    quit()
