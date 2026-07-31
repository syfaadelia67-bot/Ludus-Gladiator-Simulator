extends Node

func _ready() -> void:
    var presenter := FileAccess.get_file_as_string("res://scripts/ui/arena_finale_warning_presenter.gd")
    var arena_controller := FileAccess.get_file_as_string("res://scripts/ui/arena_experience_controller.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(presenter.contains("FINALE_WEEK := 16"))
    assert(presenter.contains("REQUIRED_WINS := 6"))
    assert(presenter.contains("EventPreparation"))
    assert(presenter.contains("FinaleWarning"))
    assert(presenter.contains("CampaignManager.get_summary()"))
    assert(presenter.contains("final_combat_resolved"))
    assert(presenter.contains("current_week == FINALE_WEEK"))
    assert(presenter.contains("COMBATE FINAL DE LA DEMO"))
    assert(presenter.contains("ADVERTENCIA FINAL"))
    assert(presenter.contains("al terminar este combate se resolverá la campaña"))
    assert(arena_controller.contains("event_card.name = \"EventPreparation\""))
    assert(project.contains("ArenaFinaleWarningPresenter=\"*res://scripts/ui/arena_finale_warning_presenter.gd\""))
    assert(project.find("WeeklyCalendarPresenter=") < project.find("ArenaFinaleWarningPresenter="))
    assert(project.find("ArenaFinaleWarningPresenter=") < project.find("StartScreenController="))

    print("Arena finale warning contract: OK")
    get_tree().quit()
