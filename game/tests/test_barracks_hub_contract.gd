extends SceneTree

func _initialize() -> void:
    var scene_text := FileAccess.get_file_as_string("res://scenes/BarracksScreen.tscn")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/barracks_screen.gd")
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var finca_text := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
    var shell_scene_text := FileAccess.get_file_as_string("res://scenes/UnifiedHudShell.tscn")
    var shell_controller_text := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")

    for required_node in ["BarracksScreen", "Landing", "PersonalCard", "FightersCard", "ContentShell", "BackToBarracksHome", "PersonalView", "FightersView", "GladiatorsButton", "BeastsButton", "GladiatorsView", "BeastsView", "PersonalList", "GladiatorList", "AssignJob", "BackToFinca"]:
        assert(scene_text.contains("name=\"%s\"" % required_node) or scene_text.contains("name = \"%s\"" % required_node))

    assert(scene_text.count("type=\"TextureButton\"") >= 2)
    assert(scene_text.contains("building_worker_quarters.png"))
    assert(scene_text.contains("facility_barracks.png"))
    assert(scene_text.contains("combat_beast.png"))
    assert(not scene_text.contains("TabContainer"))

    assert(controller_text.contains("const COVER_CARD_SIZE := Vector2(850, 478)"))
    assert(controller_text.contains("func _configure_cover_cards"))
    assert(controller_text.contains("card.custom_minimum_size = COVER_CARD_SIZE"))
    assert(controller_text.contains("func _show_barracks_home"))
    assert(controller_text.contains("func _open_personal_section"))
    assert(controller_text.contains("func _open_fighters_section"))
    assert(controller_text.contains("func _show_gladiators"))
    assert(controller_text.contains("func _show_beasts"))
    assert(controller_text.contains("RosterManager.assign_job"))
    assert(not controller_text.contains("current_tab"))
    assert(not controller_text.contains("fighter_tabs"))

    assert(hub_text.contains("\"barracks\": \"res://scenes/BarracksScreen.tscn\""))
    assert(hub_text.contains("\"barracks\": \"barracks\""))
    assert(finca_text.contains("\"barracks\": \"barracks\""))
    assert(finca_text.contains("Entrar a barracones"))
    assert(shell_scene_text.contains("name=\"Barracks\" type=\"Button\""))
    assert(shell_controller_text.contains("\"barracks\":$MainNavigation/Margin/Column/Barracks"))

    var packed := load("res://scenes/BarracksScreen.tscn")
    var script := load("res://scripts/ui/barracks_screen.gd")
    assert(packed is PackedScene)
    assert(script != null)

    var instance := (packed as PackedScene).instantiate()
    assert(instance.get_node_or_null("Landing/Cards/PersonalCard") is TextureButton)
    assert(instance.get_node_or_null("Landing/Cards/FightersCard") is TextureButton)
    assert(instance.get_node_or_null("ContentShell/PersonalView/ListPanel/Margin/Content/PersonalList") is ItemList)
    assert(instance.get_node_or_null("ContentShell/FightersView/ModeButtons/GladiatorsButton") is Button)
    assert(instance.get_node_or_null("ContentShell/FightersView/GladiatorsView/ListPanel/Margin/Content/GladiatorList") is ItemList)
    assert(instance.get_node_or_null("ContentShell/FightersView/BeastsView/Content/Icon") is TextureRect)
    instance.free()

    print("Barracks 16:9 cover navigation without tabs contract: OK")
    quit()