extends Node

func run() -> void:
    var controller_source := FileAccess.get_file_as_string("res://scripts/systems/gladiator_career_state_controller.gd")
    var training_source := FileAccess.get_file_as_string("res://scripts/systems/gladiator_training_controller.gd")
    var combat_source := FileAccess.get_file_as_string("res://scripts/systems/combat_manager_weekly.gd")
    var presenter_source := FileAccess.get_file_as_string("res://scripts/ui/gladiator_career_state_presenter.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    for state in ["activo", "veterano", "declive", "retirado"]:
        _assert(controller_source.contains("\"%s\"" % state), "Falta el estado de carrera %s." % state)
    _assert(controller_source.contains("fights >= 8 or level >= 6"), "Veterano debe alcanzarse por experiencia real dentro de la demo.")
    _assert(controller_source.contains("fights >= 14"), "Declive debe depender de una carrera extensa.")
    _assert(controller_source.contains("scars >= 2 or level >= 9"), "Declive debe considerar desgaste o nivel alto.")
    _assert(controller_source.contains("func can_retire"), "Debe validarse el retiro voluntario.")
    _assert(controller_source.contains("func retire_to_staff"), "Debe poder retirarse hacia un rol del ludus.")
    _assert(controller_source.contains("STAFF_ROLES := [\"trainer\", \"mentor\"]"), "El retiro debe ofrecer entrenador y mentor.")
    _assert(controller_source.contains("retired_gladiators.push_front"), "El retiro debe conservar un resumen histórico.")
    _assert(controller_source.contains("GladiatorCareerJournalController.add_event"), "El cambio de etapa y retiro deben registrarse en la historia.")

    _assert(training_source.contains("GladiatorCareerStateController.get_trainer_multiplier"), "Los entrenadores retirados deben mejorar el entrenamiento.")
    _assert(training_source.contains("GladiatorCareerStateController.get_mentor_morale_bonus"), "Los mentores retirados deben mejorar la moral.")
    _assert(combat_source.contains("GladiatorCareerStateController.get_combat_modifiers"), "Arena debe aplicar el estado de carrera.")
    _assert(combat_source.contains("attack_bonus"), "Veterano debe aportar ataque.")
    _assert(combat_source.contains("energy_multiplier"), "Declive debe afectar la energía.")

    _assert(presenter_source.contains("ESTADO DE CARRERA"), "La ficha debe mostrar el estado de carrera.")
    _assert(presenter_source.contains("Retirar como entrenador"), "La ficha debe ofrecer retiro como entrenador.")
    _assert(presenter_source.contains("Retirar como mentor"), "La ficha debe ofrecer retiro como mentor.")
    _assert(presenter_source.contains("El retiro es permanente"), "La interfaz debe advertir la irreversibilidad del retiro.")
    _assert(not presenter_source.contains("box.name = \"Carrera\""), "No debe agregarse otra pestaña a la ficha.")

    _assert(project_source.contains("GladiatorCareerStateController=\"*res://scripts/systems/gladiator_career_state_controller.gd\""), "El controlador debe estar registrado.")
    _assert(project_source.contains("GladiatorCareerStatePresenter=\"*res://scripts/ui/gladiator_career_state_presenter.gd\""), "El presentador debe estar registrado.")
    _assert(project_source.find("GladiatorCareerStateController=") < project_source.find("GladiatorTrainingController="), "Carrera debe cargarse antes que Entrenamiento.")
    _assert(project_source.find("GladiatorCareerStateController=") < project_source.find("GladiatorCareerStatePresenter="), "El controlador debe cargarse antes que su interfaz.")

    print("gladiator_career_state_flow_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("gladiator_career_state_flow_test: %s" % message)
        assert(condition, message)
