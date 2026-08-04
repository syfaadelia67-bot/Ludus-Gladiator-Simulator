extends Node

func _ready() -> void:
    var modal := FileAccess.get_file_as_string("res://scripts/ui/weekly_event_modal_presenter.gd")
    var arena_scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
    var arena_controller := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var bootstrap := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(modal.contains("EventManager.event_started.connect"))
    assert(modal.contains("EventManager.get_pending_event()"))
    assert(modal.contains("WeeklyEventModal"))
    assert(modal.contains("Control.MOUSE_FILTER_STOP"))
    assert(modal.contains("EventManager.resolve_choice(choice_id)"))
    assert(not modal.contains("Cerrar evento"))

    assert(arena_scene.contains("← Volver a la finca"))
    assert(arena_controller.contains("FincaHubController.show_finca()"))
    assert(arena_controller.contains("event.is_action_pressed(\"ui_cancel\")"))
    assert(bootstrap.contains("_attach_arena_screen(tabs)"))
    assert(not bootstrap.contains("_attach_arena_navigation(tabs)"))
    assert(not bootstrap.contains("_repair_arena_navigation"))
    assert(project.contains("WeeklyEventModalPresenter="))

    print("Weekly event modal and arena exit contract: OK")
    get_tree().quit()