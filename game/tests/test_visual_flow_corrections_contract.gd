extends Node

func _ready() -> void:
    var hud_bootstrap := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var arena_screen := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var event_modal := FileAccess.get_file_as_string("res://scripts/ui/weekly_event_modal_presenter.gd")
    var mastery := FileAccess.get_file_as_string("res://scripts/systems/specialization_mastery_controller.gd")
    var dossier := FileAccess.get_file_as_string("res://scripts/ui/gladiator_dossier_presenter.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(hud_bootstrap.contains("FincaHubController.prepare_scene()"))
    assert(hud_bootstrap.contains("_open_finca_as_primary_view"))
    assert(hub.contains("\"arena\": \"res://scenes/ArenaScreen.tscn\""))
    assert(hub.contains("func _show_hosted_screen"))
    assert(arena_screen.contains("BackToFinca"))
    assert(arena_screen.contains("FincaHubController.show_finca()"))
    assert(arena_screen.contains("FincaHubController.open_system(\"personal\")"))
    assert(arena_screen.contains("ui_cancel"))
    assert(arena_screen.contains("CombatManager.last_result"))

    assert(event_modal.contains("WeeklyEventModal"))
    assert(event_modal.contains("set_tab_hidden"))
    assert(event_modal.contains("La semana no puede continuar sin una decisión"))
    assert(event_modal.contains("Continuar en la finca"))
    assert(event_modal.contains("EventManager.resolve_choice"))

    assert(mastery.contains("specialization_progress"))
    assert(mastery.contains("MAX_PROGRESS := 100"))
    assert(mastery.contains("VICTORY_BONUS"))
    assert(mastery.contains("register_training_use"))
    assert(mastery.contains("func _compatible_equipment_bonus"))
    assert(mastery.contains("EquipmentManager.get_equipped_tags(person)"))

    assert(dossier.contains("Información"))
    assert(dossier.contains("Equipamiento"))
    assert(dossier.contains("Habilidades"))
    assert(dossier.contains("Rasgos"))
    assert(dossier.contains("Especialización"))
    assert(dossier.contains("RETRATO PENDIENTE"))
    assert(dossier.contains("SpecializationMasteryController.get_progress"))

    assert(project.contains("SpecializationMasteryController="))
    assert(project.contains("GladiatorDossierPresenter="))
    assert(not project.contains("ArenaOpponentPreviewPresenter="))
    assert(not project.contains("ArenaFinaleWarningPresenter="))

    print("Hosted visual flow corrections contract: OK")
    get_tree().quit()