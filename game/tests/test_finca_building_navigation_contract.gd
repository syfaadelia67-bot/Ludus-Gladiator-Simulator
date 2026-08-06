extends Node

func run() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var screen := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
    var buildings := FileAccess.get_file_as_string("res://data/buildings.json")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(hub.contains("const BUILDING_SYSTEMS"))
    assert(hub.contains('"dominus_house": "campana"'))
    assert(hub.contains('"barracks": "barracks"'))
    assert(hub.contains('"training_yard": "personal"'))
    assert(hub.contains('"forge": "forja"'))
    assert(hub.contains('"private_arena": "arena"'))
    assert(screen.contains("const BUILDING_LAYOUT"))
    assert(screen.contains("button.pressed.connect(_select_building.bind(building_id))"))
    assert(screen.contains("func _open_selected_building()"))
    assert(buildings.contains('"id": "forge"'))
    assert(buildings.contains('"id": "barracks"'))
    assert(not buildings.contains('"id": "market"'))
    assert(not project.contains("FincaBuildingNavigationController="))
    assert(not FileAccess.file_exists("res://scripts/ui/finca_building_navigation_controller.gd"))
    print("Hosted Finca building navigation contract: OK")
