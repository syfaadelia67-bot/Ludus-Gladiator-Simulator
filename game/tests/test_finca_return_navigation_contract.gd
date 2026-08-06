extends Node

func run() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var arena := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var market := FileAccess.get_file_as_string("res://scripts/ui/market_screen.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(hub.contains("func show_finca()"))
    assert(hub.contains("func return_from_gladiator_dossier"))
    assert(arena.contains("func _return_to_finca()"))
    assert(arena.contains("FincaHubController.show_finca()"))
    assert(arena.contains('event.is_action_pressed("ui_cancel")'))
    assert(market.contains("func _return_to_finca()"))
    assert(market.contains("FincaHubController.show_finca()"))
    assert(not project.contains("FincaReturnNavigationController="))
    assert(not FileAccess.file_exists("res://scripts/ui/finca_return_navigation_controller.gd"))
    print("Hosted screen return navigation contract: OK")
