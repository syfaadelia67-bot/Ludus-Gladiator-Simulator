extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

func run() -> void:
    DataRepository.load_all()
    var previous_people: Array = RosterManager.people.duplicate()
    var previous_records: Dictionary = GladiatorProgressionManager.records.duplicate(true)
    var previous_day := GameState.day

    RosterManager.people.clear()
    GladiatorProgressionManager.records.clear()
    GameState.day = 4
    var marcus_data := DataRepository.get_unique_gladiator("marcus_varro")
    marcus_data["role"] = "gladiator"
    var marcus = PERSON_SCRIPT.new(marcus_data)
    RosterManager.people.append(marcus)
    GladiatorProgressionManager.ensure_record(marcus.id)

    GladiatorRivalryController._on_combat_finished({
        "fighter_id": marcus.id,
        "enemy_unique_gladiator_id": "odran",
        "enemy_rival_id": "house_sabina",
        "event_name": "Torneo oficial",
        "victory": true,
        "surrendered": false,
        "rounds": 8
    })
    var first := GladiatorRivalryController.get_rivalry(marcus.id, "odran")
    _assert(int(first.get("encounters", 0)) == 1, "Debe registrar el primer enfrentamiento.")
    _assert(int(first.get("wins", 0)) == 1 and int(first.get("losses", 0)) == 0, "Debe registrar la victoria del jugador.")
    _assert(int(first.get("streak", 0)) == 1 and str(first.get("streak_owner", "")) == marcus.id, "La primera victoria debe iniciar una racha del jugador.")
    _assert(int(first.get("intensity", 0)) > 0, "El primer cruce debe iniciar la intensidad.")

    GameState.day = 8
    GladiatorRivalryController._on_combat_finished({
        "fighter_id": marcus.id,
        "enemy_unique_gladiator_id": "odran",
        "enemy_rival_id": "house_sabina",
        "event_name": "Exhibición semanal",
        "victory": false,
        "surrendered": true,
        "rounds": 12
    })
    var second := GladiatorRivalryController.get_rivalry(marcus.id, "odran")
    _assert(int(second.get("encounters", 0)) == 2, "Debe acumular enfrentamientos repetidos.")
    _assert(int(second.get("wins", 0)) == 1 and int(second.get("losses", 0)) == 1, "Debe mantener el marcador cara a cara.")
    _assert(int(second.get("streak", 0)) == 1 and str(second.get("streak_owner", "")) == "odran", "Una derrota debe cambiar el dueño de la racha.")
    _assert(int(second.get("recent", []).size()) == 2, "Debe conservar la cronología reciente.")
    _assert(int(second.get("intensity", 0)) > int(first.get("intensity", 0)), "La intensidad debe crecer con nuevos cruces.")

    var exported := GladiatorProgressionManager.export_state()
    GladiatorProgressionManager.records.clear()
    GladiatorProgressionManager.import_state(exported)
    var restored := GladiatorRivalryController.get_rivalry(marcus.id, "odran")
    _assert(int(restored.get("encounters", 0)) == 2, "La rivalidad debe persistir dentro del progreso del gladiador.")
    _assert(str(restored.get("rival_id", "")) == "house_sabina", "Debe conservar la casa propietaria del rival.")

    var summary := GladiatorRivalryController.get_summary(marcus.id)
    _assert(int(summary.get("count", 0)) == 1, "El resumen debe contar rivalidades únicas.")
    _assert(int(summary.get("wins", 0)) == 1 and int(summary.get("losses", 0)) == 1, "El resumen debe acumular el marcador.")

    RosterManager.people = previous_people
    GladiatorProgressionManager.records = previous_records
    GameState.day = previous_day
    RosterManager.roster_changed.emit()
    GladiatorProgressionManager.progression_changed.emit()
    print("gladiator_personal_rivalry_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("gladiator_personal_rivalry_test: %s" % message)
        assert(condition, message)
