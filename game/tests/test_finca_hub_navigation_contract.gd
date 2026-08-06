extends Node

func run() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")
    var finca_scene := FileAccess.get_file_as_string("res://scenes/FincaScreen.tscn")

    assert(hub.contains("const SCREEN_HOST_NAME := "ScreenHost""))
    assert(hub.contains('"finca": "res://scenes/FincaScreen.tscn"'))
    assert(hub.contains('"arena": "res://scenes/ArenaScreen.tscn"'))
    assert(hub.contains("func show_finca()"))
    assert(hub.contains("func open_system(system_id: String)"))
    assert(hub.contains("func get_hosted_screen(system_id: String)"))
    assert(hub.contains("func _show_hosted_screen"))
    assert(hub.contains("tabs.visible = false"))
    assert(finca_scene.contains("name="FincaScreen"") or finca_scene.contains("name = "FincaScreen""))
    assert(project.contains("FincaHubController="))
    assert(not project.contains("FincaBuildingNavigationController="))
    assert(not project.contains("FincaReturnNavigationController="))
    print("Finca ScreenHost navigation contract: OK")
