extends Node

func _ready() -> void:
    var modal := FileAccess.get_file_as_string("res://scripts/ui/weekly_event_modal_presenter.gd")
    var bootstrap := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(modal.contains("EventManager.event_started.connect"))
    assert(modal.contains("EventManager.get_pending_event()"))
    assert(modal.contains("WeeklyEventModal"))
    assert(modal.contains("Control.MOUSE_FILTER_STOP"))
    assert(modal.contains("EventManager.resolve_choice(choice_id)"))
    assert(not modal.contains("Cerrar evento"))

    assert(bootstrap.contains("← Volver a la finca"))
    assert(bootstrap.contains("FincaHubController.show_finca()"))
    assert(not bootstrap.contains("_attach_arena_navigation(tabs)"))
    assert(project.contains("WeeklyEventModalPresenter="))

    print("Weekly event modal and arena exit contract: OK")
    get_tree().quit()
