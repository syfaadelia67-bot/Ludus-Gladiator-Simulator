extends Node

func run() -> void:
    var controller_source := FileAccess.get_file_as_string("res://scripts/systems/gladiator_training_controller.gd")
    var presenter_source := FileAccess.get_file_as_string("res://scripts/ui/gladiator_training_presenter.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    _assert(controller_source.contains("const FOCUSES"), "El sistema debe definir focos de entrenamiento.")
    for focus_id in ["balanced", "strength", "agility", "endurance", "technique", "specialization"]:
        _assert(controller_source.contains("\"%s\"" % focus_id), "Falta el foco %s." % focus_id)
    _assert(controller_source.contains("func set_focus"), "Debe poder elegirse un foco individual.")
    _assert(controller_source.contains("func get_preview"), "Debe existir una previsualización semanal.")
    _assert(controller_source.contains("func process_week"), "El entrenamiento debe procesarse semanalmente.")
    _assert(controller_source.contains("last_individual_training_week"), "Debe impedirse procesar dos veces la misma semana.")
    _assert(controller_source.contains("ATTRIBUTE_THRESHOLD := 100"), "La mejora permanente debe completarse por progreso acumulado.")
    _assert(controller_source.contains("EstateManager.get_training_multiplier"), "El patio de entrenamiento debe afectar la ganancia.")
    _assert(controller_source.contains("SpecializationMasteryController.register_training_use"), "El foco de especialización debe aportar dominio.")
    _assert(controller_source.contains("Sobrecarga muscular"), "Debe existir riesgo de lesión por sobreentrenamiento.")
    _assert(controller_source.contains("GladiatorCareerJournalController.add_event"), "El entrenamiento debe registrarse en la historia del gladiador.")

    _assert(presenter_source.contains("PLAN DE ENTRENAMIENTO SEMANAL"), "La ficha debe mostrar la planificación semanal.")
    _assert(presenter_source.contains("Ganancia estimada"), "La ficha debe mostrar la ganancia estimada.")
    _assert(presenter_source.contains("Riesgo de lesión"), "La ficha debe mostrar el riesgo de lesión.")
    _assert(presenter_source.contains("GladiatorDossierPresenter.selected_person_id"), "La sección debe usar el gladiador abierto en la ficha.")
    _assert(not presenter_source.contains("box.name = \"Entrenamiento\""), "No debe agregarse una sexta pestaña a la ficha.")

    _assert(project_source.contains("GladiatorTrainingController=\"*res://scripts/systems/gladiator_training_controller.gd\""), "El controlador debe estar registrado como autoload.")
    _assert(project_source.contains("GladiatorTrainingPresenter=\"*res://scripts/ui/gladiator_training_presenter.gd\""), "El presentador debe estar registrado como autoload.")
    _assert(project_source.find("GladiatorTrainingController=") < project_source.find("GladiatorTrainingPresenter="), "El controlador debe cargarse antes que la interfaz.")

    print("gladiator_training_flow_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("gladiator_training_flow_test: %s" % message)
        assert(condition, message)
