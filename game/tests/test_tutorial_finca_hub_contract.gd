extends Node

func _ready() -> void:
    var tutorial := FileAccess.get_file_as_string("res://scripts/ui/tutorial_controller.gd")
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(tutorial.contains("FincaHubController.system_opened.connect(_on_system_opened)"))
    assert(tutorial.contains("FincaHubController.open_system(system_id)"))
    assert(tutorial.contains("FincaHubController.open_system(\"personal\")"))
    assert(tutorial.contains("\"system\":\"finca\""))
    assert(tutorial.contains("\"system\":\"personal\""))
    assert(tutorial.contains("\"system\":\"mercado\""))
    assert(tutorial.contains("\"system\":\"eventos\""))
    assert(tutorial.contains("\"system\":\"arena\""))
    assert(tutorial.contains("Abrir Personal"))
    assert(not tutorial.contains("find_child(\"Tabs\""))
    assert(not tutorial.contains("tabs.current_tab"))
    assert(not tutorial.contains("\"tab\":"))

    assert(hub.contains("\"eventos\": \"Eventos\""))
    assert(hub.contains("func open_system(system_id: String)"))

    print("Tutorial finca hub contract: OK")
    get_tree().quit()
