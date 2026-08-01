extends Node

func _ready() -> void:
    var arena_bootstrap := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var event_modal := FileAccess.get_file_as_string("res://scripts/ui/weekly_event_modal_presenter.gd")
    var mastery := FileAccess.get_file_as_string("res://scripts/systems/specialization_mastery_controller.gd")
    var dossier := FileAccess.get_file_as_string("res://scripts/ui/gladiator_dossier_presenter.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(arena_bootstrap.contains("BackToFinca"))
    assert(arena_bootstrap.contains("BackToPersonal"))
    assert(arena_bootstrap.contains("FincaHubController.show_finca()"))
    assert(arena_bootstrap.contains("FincaHubController.open_system(\"personal\")"))
    assert(arena_bootstrap.contains("ui_cancel"))

    assert(event_modal.contains("WeeklyEventModal"))
    assert(event_modal.contains("set_tab_hidden"))
    assert(event_modal.contains("La semana no puede continuar sin una decisión"))
    assert(event_modal.contains("Continuar en la finca"))
    assert(event_modal.contains("EventManager.resolve_choice"))

    assert(mastery.contains("specialization_progress"))
    assert(mastery.contains("MAX_PROGRESS := 100"))
    assert(mastery.contains("VICTORY_BONUS"))
    assert(mastery.contains("register_training_use"))
    assert(mastery.contains("_equipped_piece_count"))

    assert(dossier.contains("Información"))
    assert(dossier.contains("Equipamiento"))
    assert(dossier.contains("Habilidades"))
    assert(dossier.contains("Rasgos"))
    assert(dossier.contains("Especialización"))
    assert(dossier.contains("RETRATO PENDIENTE"))
    assert(dossier.contains("SpecializationMasteryController.get_progress"))

    assert(project.contains("SpecializationMasteryController="))
    assert(project.contains("GladiatorDossierPresenter="))

    print("Visual flow corrections contract: OK")
    get_tree().quit()
