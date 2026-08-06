extends Node

func run() -> void:
    var tutorial := FileAccess.get_file_as_string("res://scripts/ui/tutorial_controller.gd")
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(tutorial.contains('"system":"finca"'))
    assert(tutorial.contains('"system":"barracks"'))
    assert(tutorial.contains('"system":"mercado"'))
    assert(tutorial.contains('"system":"campana"'))
    assert(tutorial.contains('"system":"arena"'))
    assert(tutorial.contains("FincaHubController.show_finca()"))
    assert(tutorial.contains("FincaHubController.open_system(system_id)"))
    assert(tutorial.contains('FincaHubController.open_system("barracks")'))
    assert(tutorial.contains("FincaHubController.system_opened.connect"))
    assert(hub.contains('"finca": "res://scenes/FincaScreen.tscn"'))
    assert(hub.contains('"barracks": "res://scenes/BarracksScreen.tscn"'))
    print("Finca-centered hosted tutorial contract: OK")
