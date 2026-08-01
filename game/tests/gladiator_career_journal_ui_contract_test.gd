extends Node

func run() -> void:
    var journal_source := FileAccess.get_file_as_string("res://scripts/systems/gladiator_career_journal_controller.gd")
    var presenter_source := FileAccess.get_file_as_string("res://scripts/ui/gladiator_career_journal_presenter.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    _assert(journal_source.contains("CombatManager.combat_finished.connect"), "El diario debe registrar combates reales.")
    _assert(journal_source.contains("TraitManager.trait_awarded.connect"), "El diario debe registrar rasgos obtenidos.")
    _assert(journal_source.contains("specialization_mastered.connect"), "El diario debe registrar dominio de especialización.")
    _assert(journal_source.contains("MAX_EVENTS := 40"), "El diario debe tener un límite explícito.")
    _assert(journal_source.contains("record[\"background\"]"), "Los antecedentes deben persistirse en el registro de progresión.")
    _assert(journal_source.contains("record[\"career_events\"]"), "Los eventos deben persistirse en el registro de progresión.")

    _assert(presenter_source.contains("JOURNAL_SECTION_NAME := \"CareerJournalSection\""), "La ficha debe crear una sección de carrera identificable.")
    _assert(presenter_source.contains("tabs.get_node_or_null(\"Información\")"), "La historia debe integrarse dentro de Información y no crear una sexta pestaña.")
    _assert(presenter_source.contains("HISTORIA Y CARRERA"), "La ficha debe mostrar un encabezado de historia y carrera.")
    _assert(presenter_source.contains("mini(10, events.size())"), "La ficha debe limitar la cronología visible reciente.")
    _assert(presenter_source.contains("GladiatorDossierPresenter"), "El presentador debe reutilizar la ficha existente.")

    var journal_order := project_source.find("GladiatorCareerJournalController=")
    var dossier_order := project_source.find("GladiatorDossierPresenter=")
    var presenter_order := project_source.find("GladiatorCareerJournalPresenter=")
    _assert(journal_order >= 0, "El diario debe estar registrado como autoload.")
    _assert(dossier_order >= 0 and presenter_order > dossier_order, "El presentador de carrera debe cargarse después de la ficha principal.")

    print("gladiator_career_journal_ui_contract_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("gladiator_career_journal_ui_contract_test: %s" % message)
        assert(condition, message)
