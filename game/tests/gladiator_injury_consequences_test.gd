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
        "id":"injury_consequences_fighter",
        "name":"Herido",
        "role":"gladiator",
        "origin":"Hispania",
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

    fighter.apply_injury("Fractura grave", 3, 3)
    record["active_injury"] = {
        "name":"Fractura grave",
        "severity":3,
        "started_week":2,
        "recovery_weeks":3,
        "event_name":"Combate clandestino"
    }
    _assert(not fighter.is_available_for_combat(), "Una lesión activa debe bloquear el combate.")
    _assert(fighter.get_injury_summary().contains("semana"), "La recuperación debe presentarse en semanas.")
    _assert(int(GladiatorInjuryController.get_active_injury(fighter.id).get("severity", 0)) == 3, "La gravedad activa debe conservarse.")

    fighter.injury_days = 0
    fighter.injury_severity = 0
    fighter.injury_name = ""
    var agility_before := fighter.agility
    GladiatorInjuryController._complete_recovery(fighter, record, record.get("active_injury", {}))

    var scars := GladiatorInjuryController.get_scars(fighter.id)
    _assert(scars.size() == 1, "Una lesión grave debe dejar una cicatriz permanente.")
    _assert(str(scars[0].get("name", "")).contains("fractura"), "La fractura grave debe producir una secuela identificable.")
    _assert(fighter.agility == agility_before - 1, "La secuela de fractura debe reducir Agilidad en un punto.")
    _assert(GladiatorInjuryController.get_active_injury(fighter.id).is_empty(), "La lesión activa debe limpiarse al completar la recuperación.")

    var exported := GladiatorProgressionManager.export_state()
    GladiatorProgressionManager.records.clear()
    GladiatorProgressionManager.import_state(exported)
    GladiatorInjuryController._sanitize_all()
    _assert(GladiatorInjuryController.get_scars(fighter.id).size() == 1, "Las cicatrices deben persistir en el guardado de progresión.")

    var weekly_source := FileAccess.get_file_as_string("res://scripts/systems/combat_manager_weekly.gd")
    _assert(weekly_source.contains("WEEKLY_INJURIES"), "El combate semanal debe usar un catálogo de lesiones.")
    _assert(weekly_source.contains("severity = 3"), "El combate semanal debe poder producir lesiones graves.")
    _assert(weekly_source.contains("recuperación: %d semana(s)"), "El resultado debe informar recuperación semanal.")

    var project_source := FileAccess.get_file_as_string("res://project.godot")
    _assert(project_source.contains("GladiatorInjuryController=\"*res://scripts/systems/gladiator_injury_controller.gd\""), "El controlador de lesiones debe estar registrado como autoload.")

    var presenter_source := FileAccess.get_file_as_string("res://scripts/ui/gladiator_career_journal_presenter.gd")
    _assert(presenter_source.contains("ESTADO MÉDICO"), "La ficha debe mostrar el estado médico.")
    _assert(presenter_source.contains("Cicatrices permanentes"), "La ficha debe mostrar cicatrices permanentes.")

    RosterManager.people = previous_people
    GladiatorProgressionManager.records = previous_records
    print("gladiator_injury_consequences_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("gladiator_injury_consequences_test: %s" % message)
        assert(condition, message)
