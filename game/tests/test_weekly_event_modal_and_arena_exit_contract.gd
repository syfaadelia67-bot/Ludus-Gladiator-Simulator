extends Node

func run() -> void:
    var modal := FileAccess.get_file_as_string("res://scripts/ui/weekly_event_modal_presenter.gd")
    var arena_scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
    var arena := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(modal.contains("EventManager.event_started.connect"))
    assert(modal.contains("EventManager.get_pending_event()"))
    assert(modal.contains("WeeklyEventModal"))
    assert(modal.contains("Control.MOUSE_FILTER_STOP"))
    assert(modal.contains("EventManager.resolve_choice(choice_id)"))
    assert(modal.contains("FincaHubController.show_finca()"))
    assert(not modal.contains("Cerrar evento"))
    assert(arena_scene.contains("BackToFinca"))
    assert(arena.contains("func _return_to_finca()"))
    assert(arena.contains("FincaHubController.show_finca()"))
    assert(arena.contains('event.is_action_pressed("ui_cancel")'))
    assert(project.contains("WeeklyEventModalPresenter="))
    print("Weekly event modal and hosted Arena exit contract: OK")
