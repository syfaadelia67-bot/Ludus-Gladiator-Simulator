extends Node

func _ready() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var controller := FileAccess.get_file_as_string("res://scripts/ui/finca_building_navigation_controller.gd")
    var buildings := FileAccess.get_file_as_string("res://data/buildings.json")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(hub.contains("const BUILDING_SYSTEMS"))
    assert(hub.contains("\"dominus_house\": \"campana\""))
    assert(hub.contains("\"barracks\": \"personal\""))
    assert(hub.contains("\"training_yard\": \"personal\""))
    assert(hub.contains("\"forge\": \"forja\""))
    assert(hub.contains("\"private_arena\": \"arena\""))
    assert(hub.contains("func open_building_system"))
    assert(hub.contains("EstateManager.canonicalize_building_id"))

    assert(controller.contains("item_activated.connect"))
    assert(controller.contains("get_item_metadata"))
    assert(controller.contains("FincaHubController.open_building_system"))
    assert(controller.contains("Seleccioná una instalación para ver sus datos"))

    assert(buildings.contains("\"id\": \"forge\""))
    assert(buildings.contains("\"id\": \"barracks\""))
    assert(not buildings.contains("\"id\": \"market\""))
    assert(not hub.contains("\"market\": \"mercado\""))

    var hub_index := project.find("FincaHubController=")
    var navigation_index := project.find("FincaBuildingNavigationController=")
    assert(hub_index >= 0)
    assert(navigation_index > hub_index)

    print("Finca building navigation contract: OK")
    get_tree().quit()
