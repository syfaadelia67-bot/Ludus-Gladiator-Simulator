extends SceneTree

func _initialize() -> void:
    var scene_text := FileAccess.get_file_as_string("res://scenes/FincaScreen.tscn")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

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
    assert(controller_text.contains("tabs.tabs_visible = not active"))
    assert(controller_text.contains("EventManager.get_pending_event()"))
    assert(controller_text.contains("CombatManager.get_current_event_details()"))
    assert(controller_text.contains("EstateManager.can_upgrade"))

    assert(bootstrap_text.contains("preload(\"res://scenes/FincaScreen.tscn\")"))
    assert(bootstrap_text.contains("_attach_finca_screen(tabs)"))
    assert(bootstrap_text.contains("_select_finca_as_primary_view"))
    assert(bootstrap_text.contains("primary_finca_screen"))

    assert(hub_text.contains("\"relaciones\": \"Relaciones\""))
    assert(hub_text.contains("\"infirmary\": \"personal\""))
    assert(hub_text.contains("\"kitchen\": \"economia\""))
    assert(hub_text.contains("EstateManager.is_locked(canonical_id)"))

    var finca_scene := load("res://scenes/FincaScreen.tscn")
    var finca_script := load("res://scripts/ui/finca_screen.gd")
    assert(finca_scene is PackedScene)
    assert(finca_script != null)

    var instance := (finca_scene as PackedScene).instantiate()
    assert(instance.get_node_or_null("TopHUD") != null)
    assert(instance.get_node_or_null("MainNavigation") != null)
    assert(instance.get_node_or_null("Center/WorldPanel/WorldMargin/WorldArea") != null)
    assert(instance.get_node_or_null("Center/BuildingDetailsPanel") != null)
    assert(instance.get_node_or_null("BottomStatusBar") != null)
    instance.free()

    print("Finca main screen contract: OK")
    quit()
