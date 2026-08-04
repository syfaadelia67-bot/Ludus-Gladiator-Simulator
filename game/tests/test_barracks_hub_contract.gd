extends SceneTree

func _initialize() -> void:
    var scene_text := FileAccess.get_file_as_string("res://scenes/BarracksScreen.tscn")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/barracks_screen.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var finca_text := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
    var shell_scene_text := FileAccess.get_file_as_string("res://scenes/UnifiedHudShell.tscn")
    var shell_controller_text := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")

    for required_node in [
        "BarracksScreen",
        "PersonalButton",
        "FightersButton",
        "Sections",
        "Personal",
        "Luchadores",
        "FighterTabs",
        "Gladiadores",
        "Bestias",
        "PersonalList",
        "GladiatorList",
        "AssignJob",
        "BackToFinca"
    ]:
        assert(scene_text.contains("name=\"%s\"" % required_node) or scene_text.contains("name = \"%s\"" % required_node))

    assert(scene_text.contains("tabs_visible = false"))
    assert(scene_text.contains("building_worker_quarters.png"))
    assert(scene_text.contains("facility_barracks.png"))
    assert(scene_text.contains("combat_beast.png"))
    assert(scene_text.contains("PERSONAL\\nEsclavos y trabajadores"))
    assert(scene_text.contains("LUCHADORES\\nGladiadores y bestias"))

    assert(controller_text.contains("str(person.role) == \"gladiator\""))
    assert(controller_text.contains("str(person.role) != \"gladiator\""))
    assert(controller_text.contains("RosterManager.assign_job"))
    assert(controller_text.contains("_show_personal"))
    assert(controller_text.contains("_show_fighters"))
    assert(controller_text.contains("fighter_tabs.current_tab = 0"))
    assert(controller_text.contains("EstateManager.get_building_data(\"beast_area\")"))
    assert(controller_text.contains("FincaHubController.open_system(\"progresion\")"))
    assert(controller_text.contains("FincaHubController.open_system(\"equipamiento\")"))
    assert(controller_text.contains("FincaHubController.open_system(\"arena\")"))
    assert(not controller_text.contains("grab_focus()"))

    assert(bootstrap_text.contains("{\"name\":\"Barracones\", \"scene\":preload(\"res://scenes/BarracksScreen.tscn\")}"))
    assert(hub_text.contains("\"barracks\": \"Barracones\""))
    assert(hub_text.contains("\"barracks\": \"barracks\""))
    assert(finca_text.contains("\"barracks\":\"barracks\""))
    assert(finca_text.contains("Entrar a barracones"))
    assert(shell_scene_text.contains("text = \"BARRACONES\""))
    assert(shell_controller_text.contains("\"barracks\":\"Barracones\""))
    assert(shell_controller_text.contains("\"barracks\":$MainNavigation/Margin/Row/Personal"))

    var packed := load("res://scenes/BarracksScreen.tscn")
    var script := load("res://scripts/ui/barracks_screen.gd")
    assert(packed is PackedScene)
    assert(script != null)

    var instance := (packed as PackedScene).instantiate()
    assert(instance.get_node_or_null("PrimaryChoices/PersonalButton") is Button)
    assert(instance.get_node_or_null("PrimaryChoices/FightersButton") is Button)
    assert(instance.get_node_or_null("Sections") is TabContainer)
    assert(instance.get_node_or_null("Sections/Personal/ListPanel/Margin/Content/PersonalList") is ItemList)
    assert(instance.get_node_or_null("Sections/Luchadores/FighterTabs") is TabContainer)
    assert(instance.get_node_or_null("Sections/Luchadores/FighterTabs/Gladiadores/ListPanel/Margin/Content/GladiatorList") is ItemList)
    assert(instance.get_node_or_null("Sections/Luchadores/FighterTabs/Bestias/Content/Icon") is TextureRect)
    instance.free()

    print("Barracks personnel and fighters hub contract: OK")
    quit()
