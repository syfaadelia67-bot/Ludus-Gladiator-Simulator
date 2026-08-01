extends Node

func _ready() -> void:
    var controller := FileAccess.get_file_as_string("res://scripts/ui/finca_building_navigation_controller.gd")
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(controller.contains("OpenBuildingSystem"))
    assert(controller.contains("BUILDING_PANEL_PATH"))
    assert(controller.contains("item_selected.connect(_on_building_selected)"))
    assert(controller.contains("item_activated.connect(_on_building_activated)"))
    assert(controller.contains("access_button.pressed.connect(_on_access_pressed)"))
    assert(controller.contains("FincaHubController.get_building_system_id"))
    assert(controller.contains("FincaHubController.open_building_system"))
    assert(controller.contains("Abrir administración y campaña"))
    assert(controller.contains("Abrir gestión de personal"))
    assert(controller.contains("Entrar a la forja"))
    assert(controller.contains("Entrar a la arena"))
    assert(controller.contains("access_button.visible = not system_id.is_empty()"))
    assert(controller.contains("_restore_selected_building"))

    assert(hub.contains("func get_building_system_id"))
    assert(hub.contains("func open_building_system"))
    assert(hub.contains('"forge": "forja"'))
    assert(hub.contains('"barracks": "personal"'))
    assert(hub.contains('"private_arena": "arena"'))

    print("Finca building contextual access contract: OK")
    get_tree().quit()
