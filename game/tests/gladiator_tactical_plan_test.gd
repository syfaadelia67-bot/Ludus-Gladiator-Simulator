extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

func run() -> void:
    DataRepository.load_all()
    var previous_people: Array = RosterManager.people.duplicate()
    var previous_records: Dictionary = GladiatorProgressionManager.records.duplicate(true)

    var person = PERSON_SCRIPT.new({
        "id": "tactical_test_gladiator",
        "name": "Tactical Test",
        "role": "gladiator",
        "strength": 6,
        "agility": 6,
        "endurance": 6,
        "intelligence": 6,
        "technique": 6
    })
    RosterManager.people = [person]
    var record := GladiatorProgressionManager.ensure_record(person.id)

    var available := GladiatorProgressionManager.get_available_ability_ids(person.id)
    _assert(available.size() >= 2, "Debe haber al menos dos habilidades disponibles para probar el plan táctico.")
    var first := str(available[0])
    var second := str(available[1])
    record["abilities"] = {first: 1, second: 1}

    var plan := [
        {"ability_id": first, "condition": "opening"},
        {"ability_id": second, "condition": "self_low_health"}
    ]
    _assert(GladiatorProgressionManager.set_tactical_plan(person.id, plan), "Debe aceptar órdenes con habilidades aprendidas.")
    var stored := GladiatorProgressionManager.get_tactical_plan(person.id)
    _assert(stored.size() == 2, "Debe conservar dos órdenes tácticas.")
    _assert(str(stored[0].get("condition", "")) == "opening", "Debe conservar el orden y la condición de apertura.")
    _assert(str(stored[1].get("condition", "")) == "self_low_health", "Debe conservar la condición de poca vida.")

    var duplicate := [
        {"ability_id": first, "condition": "always"},
        {"ability_id": first, "condition": "opening"}
    ]
    _assert(not GladiatorProgressionManager.set_tactical_plan(person.id, duplicate), "No debe aceptar la misma habilidad dos veces.")

    var invalid_condition := [{"ability_id": first, "condition": "condicion_inexistente"}]
    _assert(GladiatorProgressionManager.set_tactical_plan(person.id, invalid_condition), "Debe migrar condiciones desconocidas sin romper el plan.")
    _assert(str(GladiatorProgressionManager.get_tactical_plan(person.id)[0].get("condition", "")) == "always", "Las condiciones desconocidas deben canonicalizarse como siempre.")

    var too_many: Array = []
    for index in range(5):
        too_many.append({"ability_id": first if index % 2 == 0 else second, "condition": "always"})
    _assert(not GladiatorProgressionManager.set_tactical_plan(person.id, too_many), "No debe aceptar más de cuatro órdenes ni duplicados encubiertos.")

    GladiatorProgressionManager.set_tactical_plan(person.id, plan)
    var exported := GladiatorProgressionManager.export_state()
    GladiatorProgressionManager.records.clear()
    GladiatorProgressionManager.import_state(exported)
    _assert(GladiatorProgressionManager.get_tactical_plan(person.id).size() == 2, "El plan táctico debe persistir al exportar e importar.")

    var source := FileAccess.get_file_as_string("res://scripts/ui/gladiator_tactical_plan_presenter.gd")
    _assert(source.contains("PLAN TÁCTICO"), "La ficha debe mostrar el editor de plan táctico.")
    _assert(source.contains("range(4)"), "La interfaz debe ofrecer cuatro prioridades.")
    _assert(source.contains("set_tactical_plan"), "La interfaz debe guardar mediante el manager de progresión.")
    var project := FileAccess.get_file_as_string("res://project.godot")
    _assert(project.contains("GladiatorTacticalPlanPresenter"), "El presentador táctico debe estar registrado como autoload.")

    RosterManager.people = previous_people
    GladiatorProgressionManager.records = previous_records
    RosterManager.roster_changed.emit()
    GladiatorProgressionManager.progression_changed.emit()
    print("gladiator_tactical_plan_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("gladiator_tactical_plan_test: %s" % message)
        assert(condition, message)
