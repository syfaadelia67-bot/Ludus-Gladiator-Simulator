extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

func run() -> void:
    DataRepository.load_all()
    GladiatorProgressionManager._load_catalogs()
    TraitManager._load_catalog()

    var previous_people: Array = RosterManager.people.duplicate()
    var previous_records: Dictionary = GladiatorProgressionManager.records.duplicate(true)
    RosterManager.people.clear()
    GladiatorProgressionManager.records.clear()

    var fighter: LudusPerson = PERSON_SCRIPT.new({
        "id":"career_journal_fighter",
        "name":"Aulus",
        "origin":"Hispania",
        "role":"gladiator",
        "strength":6,
        "agility":6,
        "endurance":6,
        "intelligence":5,
        "technique":5,
        "health":50,
        "traits":["freedom_seeker"]
    })
    RosterManager.people.append(fighter)

    var background := GladiatorCareerJournalController.get_background(fighter.id)
    _assert(background.contains("Hispania"), "El antecedente debe conservar el origen del gladiador.")
    _assert(background.to_lower().contains("libertad"), "El antecedente debe reflejar rasgos relevantes.")

    _assert(GladiatorCareerJournalController.add_event(fighter.id, "combat", "Primera victoria", "Venció en la arena."), "Debe poder registrarse un hito de carrera.")
    _assert(GladiatorCareerJournalController.add_event(fighter.id, "injury", "Herida", "Recibió una herida leve."), "Debe poder registrarse una lesión.")
    var summary := GladiatorCareerJournalController.get_summary(fighter.id)
    _assert(int(summary.get("combat_events", 0)) == 1, "El resumen debe contar combates.")
    _assert(int(summary.get("injuries", 0)) == 1, "El resumen debe contar lesiones.")

    var exported := GladiatorProgressionManager.export_state()
    GladiatorProgressionManager.records.clear()
    GladiatorProgressionManager.import_state(exported)
    GladiatorCareerJournalController._ensure_all_journals()

    _assert(GladiatorCareerJournalController.get_background(fighter.id) == background, "El antecedente debe persistir al exportar e importar.")
    _assert(GladiatorCareerJournalController.get_events(fighter.id).size() == 2, "Los eventos de carrera deben persistir.")

    for index in range(GladiatorCareerJournalController.MAX_EVENTS + 5):
        GladiatorCareerJournalController.add_event(fighter.id, "milestone", "Hito %d" % index, "Evento de prueba")
    var limited := GladiatorCareerJournalController.get_events(fighter.id)
    _assert(limited.size() == GladiatorCareerJournalController.MAX_EVENTS, "El diario debe respetar su límite máximo.")
    _assert(str(limited[0].get("title", "")) == "Hito %d" % (GladiatorCareerJournalController.MAX_EVENTS + 4), "El evento más reciente debe quedar primero.")

    var record := GladiatorProgressionManager.ensure_record(fighter.id)
    record["career_events"] = [null, {"week":0,"type":"","title":"","description":""}]
    GladiatorCareerJournalController._ensure_all_journals()
    var sanitized := GladiatorCareerJournalController.get_events(fighter.id)
    _assert(sanitized.size() == 1, "La migración debe descartar entradas inválidas.")
    _assert(int(sanitized[0].get("week", 0)) == 1, "La semana migrada debe limitarse a un valor válido.")
    _assert(str(sanitized[0].get("title", "")).is_empty(), "El contenido válido existente no debe inventarse durante la migración.")

    RosterManager.people = previous_people
    GladiatorProgressionManager.records = previous_records
    print("gladiator_career_journal_persistence_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("gladiator_career_journal_persistence_test: %s" % message)
        assert(condition, message)
