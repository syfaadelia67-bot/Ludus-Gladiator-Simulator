extends Node

func _ready() -> void:
    var controller := FileAccess.get_file_as_string("res://scripts/ui/finca_return_navigation_controller.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(controller.contains("ReturnToFinca"))
    assert(controller.contains("Volver a la finca"))
    assert(controller.contains("FincaHubController.show_finca()"))
    assert(controller.contains("tabs.tab_changed.connect"))
    assert(controller.contains("FincaHubController.system_opened.connect"))
    assert(controller.contains("get_current_system_id() != \"finca\""))
    assert(controller.contains("TOP_BUTTONS_PATH"))

    var hub_index := project.find("FincaHubController=")
    var building_index := project.find("FincaBuildingNavigationController=")
    var return_index := project.find("FincaReturnNavigationController=")
    var start_index := project.find("StartScreenController=")
    assert(hub_index >= 0)
    assert(building_index > hub_index)
    assert(return_index > building_index)
    assert(start_index > return_index)

    print("Finca return navigation contract: OK")
    get_tree().quit()
