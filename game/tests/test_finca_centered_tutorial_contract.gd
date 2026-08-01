extends Node

func _ready() -> void:
    var tutorial := FileAccess.get_file_as_string("res://scripts/ui/tutorial_controller.gd")
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(tutorial.contains('"system":"finca"'))
    assert(tutorial.contains('"system":"personal"'))
    assert(tutorial.contains('"system":"mercado"'))
    assert(tutorial.contains('"system":"campana"'))
    assert(tutorial.contains('"system":"arena"'))
    assert(not tutorial.contains('"system":"eventos"'))

    assert(tutorial.contains("FincaHubController.show_finca()"))
    assert(tutorial.contains("FincaHubController.open_system(system_id)"))
    assert(tutorial.contains('FincaHubController.open_system("personal")'))
    assert(tutorial.contains("FincaHubController.system_opened.connect"))

    assert(hub.contains('"finca": "Finca"'))
    assert(hub.contains('"campana": "Campaña"'))
    assert(hub.contains("func show_finca()"))
    assert(hub.contains("func open_system(system_id: String)"))

    print("Finca-centered tutorial navigation contract: OK")
    get_tree().quit()
