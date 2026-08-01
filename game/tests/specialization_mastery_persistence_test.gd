extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

func run() -> void:
    DataRepository.load_all()
    GladiatorProgressionManager._load_catalogs()

    var previous_people: Array = RosterManager.people.duplicate()
    var previous_records: Dictionary = GladiatorProgressionManager.records.duplicate(true)
    RosterManager.people.clear()
    GladiatorProgressionManager.records.clear()

    var fighter: LudusPerson = PERSON_SCRIPT.new({
        "id":"mastery_persistence_fighter",
        "name":"Maestría",
        "role":"gladiator",
        "strength":6,
        "agility":6,
        "endurance":6,
        "intelligence":5,
        "technique":5,
        "health":50,
        "traits":[]
    })
    RosterManager.people.append(fighter)

    var record := GladiatorProgressionManager.ensure_record(fighter.id)
    _assert(not SpecializationMasteryController.has_selected_specialization(fighter.id), "Un gladiador nuevo no debe tener una especialización elegida.")
    _assert(SpecializationMasteryController.register_training_use(fighter.id) == 0, "El entrenamiento no debe aumentar dominio antes de elegir especialización.")
    _assert(SpecializationMasteryController.get_progress(fighter.id) == 0, "El dominio inicial debe ser 0%.")
    _assert(not SpecializationMasteryController.select_specialization(fighter.id, GladiatorProgressionManager.DEFAULT_SPECIALIZATION), "La clase base no debe confirmarse como especialización final.")

    record["level"] = 3
    var specialization_id := _first_advanced_specialization()
    _assert(not specialization_id.is_empty(), "Debe existir al menos una especialización avanzada.")
    _assert(SpecializationMasteryController.select_specialization(fighter.id, specialization_id), "Un gladiador de nivel 3 debe poder elegir una especialización avanzada.")
    _assert(SpecializationMasteryController.has_selected_specialization(fighter.id), "La especialización elegida debe quedar registrada.")
    _assert(SpecializationMasteryController.get_progress(fighter.id) == 0, "Elegir especialización debe comenzar el dominio en 0%.")

    fighter.assign_job("training")
    var training_gain := SpecializationMasteryController.register_training_use(fighter.id)
    _assert(training_gain >= SpecializationMasteryController.TRAINING_BASE_PROGRESS, "Entrenar debe aumentar el dominio después de elegir especialización.")

    var mutable_record := GladiatorProgressionManager.ensure_record(fighter.id)
    mutable_record["specialization_progress"] = 47
    mutable_record["specialization_mastered"] = false
    var exported := GladiatorProgressionManager.export_state()

    GladiatorProgressionManager.records.clear()
    GladiatorProgressionManager.import_state(exported)
    SpecializationMasteryController._ensure_records()
    _assert(SpecializationMasteryController.get_progress(fighter.id) == 47, "El dominio debe conservarse al exportar e importar el guardado.")
    _assert(not SpecializationMasteryController.is_mastered(fighter.id), "47% no debe considerarse especialización completada.")

    var restored := GladiatorProgressionManager.ensure_record(fighter.id)
    restored["specialization_progress"] = 140
    SpecializationMasteryController._ensure_records()
    _assert(SpecializationMasteryController.get_progress(fighter.id) == 100, "El dominio importado debe limitarse a 100%.")
    _assert(SpecializationMasteryController.is_mastered(fighter.id), "100% debe marcar la especialización como completada.")

    restored["specialization"] = GladiatorProgressionManager.DEFAULT_SPECIALIZATION
    restored["specialization_progress"] = 75
    SpecializationMasteryController._ensure_records()
    _assert(SpecializationMasteryController.get_progress(fighter.id) == 0, "Una partida sin especialización elegida no debe conservar dominio inválido.")

    RosterManager.people = previous_people
    GladiatorProgressionManager.records = previous_records
    print("specialization_mastery_persistence_test: OK")

func _first_advanced_specialization() -> String:
    for specialization_id in GladiatorProgressionManager.get_specialization_ids():
        if specialization_id != GladiatorProgressionManager.DEFAULT_SPECIALIZATION:
            return specialization_id
    return ""

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("specialization_mastery_persistence_test: %s" % message)
        assert(condition, message)
