extends Node

func run() -> void:
    var screen := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
    var scene := FileAccess.get_file_as_string("res://scenes/FincaScreen.tscn")
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(screen.contains("const BUILDING_SYSTEMS"))
    assert(screen.contains("enter_button.pressed.connect(_open_selected_building)"))
    assert(screen.contains("func _open_selected_building()"))
    assert(screen.contains("FincaHubController.open_system(system_id)"))
    assert(screen.contains("Entrar a administración"))
    assert(screen.contains("Entrar a barracones"))
    assert(screen.contains("Entrar a la forja"))
    assert(screen.contains("enter_button.disabled = system_id.is_empty()"))
    assert(scene.contains('name="Enter"') or scene.contains('name = "Enter"'))
    assert(hub.contains("func get_building_system_id"))
    assert(hub.contains("func open_building_system"))
    print("Hosted Finca building contextual access contract: OK")
