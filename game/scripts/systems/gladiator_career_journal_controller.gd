extends Node

signal journal_changed(person_id: String)

const MAX_EVENTS := 40

func _ready() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    GladiatorProgressionManager.specialization_changed.connect(_on_specialization_changed)
    SpecializationMasteryController.specialization_mastered.connect(_on_specialization_mastered)
    TraitManager.trait_awarded.connect(_on_trait_awarded)
    RosterManager.roster_changed.connect(_ensure_all_journals)
    SaveManager.load_completed.connect(func(_path: String): _ensure_all_journals())
    call_deferred("_ensure_all_journals")

func get_background(person_id: String) -> String:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return ""
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _ensure_journal(person, record)
    return str(record.get("background", ""))

func get_events(person_id: String) -> Array[Dictionary]:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return []
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _ensure_journal(person, record)
    var result: Array[Dictionary] = []
    result.assign(record.get("career_events", []))
    return result.duplicate(true)

func add_event(person_id: String, event_type: String, title: String, description: String, data: Dictionary = {}) -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        return false
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _ensure_journal(person, record)
    var events: Array = record.get("career_events", [])
    var entry := {
        "week": GameState.get_week(),
        "type": event_type,
        "title": title,
        "description": description,
        "data": data.duplicate(true)
    }
    events.push_front(entry)
    if events.size() > MAX_EVENTS:
        events.resize(MAX_EVENTS)
    record["career_events"] = events
    journal_changed.emit(person_id)
    GladiatorProgressionManager.progression_changed.emit()
    return true

func get_summary(person_id: String) -> Dictionary:
    var events := get_events(person_id)
    var combat_count := 0
    var injury_count := 0
    var milestone_count := 0
    for entry in events:
        match str(entry.get("type", "")):
            "combat": combat_count += 1
            "injury": injury_count += 1
            _: milestone_count += 1
    return {
        "background": get_background(person_id),
        "events": events,
        "combat_events": combat_count,
        "injuries": injury_count,
        "milestones": milestone_count
    }

func _ensure_all_journals() -> void:
    for person in RosterManager.get_people():
        if person.role != "gladiator":
            continue
        var record := GladiatorProgressionManager.ensure_record(person.id)
        _ensure_journal(person, record)

func _ensure_journal(person, record: Dictionary) -> void:
    if str(record.get("background", "")).is_empty():
        record["background"] = _build_background(person)
    var raw_events = record.get("career_events", [])
    var sanitized: Array[Dictionary] = []
    if raw_events is Array:
        for raw_entry in raw_events:
            if not raw_entry is Dictionary or sanitized.size() >= MAX_EVENTS:
                continue
            var entry: Dictionary = raw_entry
            sanitized.append({
                "week": maxi(1, int(entry.get("week", 1))),
                "type": str(entry.get("type", "milestone")),
                "title": str(entry.get("title", "Hito de carrera")),
                "description": str(entry.get("description", "")),
                "data": entry.get("data", {}).duplicate(true) if entry.get("data", {}) is Dictionary else {}
            })
    record["career_events"] = sanitized

func _build_background(person) -> String:
    var origin := str(person.origin)
    var opening := "%s llegó al ludus desde %s." % [person.display_name, origin]
    var motive := "Su pasado permanece fragmentado, pero la arena comienza a definir una nueva identidad."
    if person.traits.has("freedom_seeker"):
        motive = "Cada entrenamiento está ligado a una ambición concreta: conseguir la libertad."
    elif person.traits.has("arena_lover"):
        motive = "A diferencia de muchos cautivos, encontró en la arena un lugar donde desea ser recordado."
    elif person.traits.has("vengeful"):
        motive = "Carga una deuda de sangre que todavía no ha sido saldada."
    elif person.traits.has("protector"):
        motive = "Su lealtad nace del impulso de proteger a quienes considera parte de su nueva casa."
    return "%s %s" % [opening, motive]

func _on_combat_finished(result: Dictionary) -> void:
    var person_id := str(result.get("fighter_id", ""))
    if person_id.is_empty():
        return
    var victory := bool(result.get("victory", false))
    var surrendered := bool(result.get("surrendered", false))
    var outcome := "Victoria" if victory else ("Rendición" if surrendered else "Derrota")
    var enemy := str(result.get("enemy", "un rival desconocido"))
    add_event(person_id, "combat", "%s en %s" % [outcome, result.get("event_name", "la arena")], "%s combatió contra %s durante %d ronda(s)." % [RosterManager.get_person(person_id).display_name, enemy, int(result.get("rounds", 0))], {
        "victory": victory,
        "surrendered": surrendered,
        "enemy": enemy,
        "reward": int(result.get("reward", 0)),
        "reputation": int(result.get("reputation", 0))
    })
    var injury := str(result.get("injury", ""))
    if not injury.is_empty():
        add_event(person_id, "injury", "Herida en combate", injury, {"event_name": str(result.get("event_name", "Arena"))})

func _on_specialization_changed(person_id: String, specialization_id: String) -> void:
    if specialization_id == GladiatorProgressionManager.DEFAULT_SPECIALIZATION:
        return
    add_event(person_id, "specialization", "Especialización elegida", "%s inició el camino de %s." % [RosterManager.get_person(person_id).display_name, GladiatorProgressionManager.get_specialization_name(specialization_id)], {"specialization": specialization_id})

func _on_specialization_mastered(person_id: String, specialization_id: String) -> void:
    add_event(person_id, "mastery", "Especialización dominada", "%s alcanzó el 100%% de dominio como %s." % [RosterManager.get_person(person_id).display_name, GladiatorProgressionManager.get_specialization_name(specialization_id)], {"specialization": specialization_id})

func _on_trait_awarded(person_id: String, trait_id: String) -> void:
    add_event(person_id, "trait", "Nuevo rasgo", "%s obtuvo el rasgo %s." % [RosterManager.get_person(person_id).display_name, TraitManager.get_trait_name(trait_id)], {"trait_id": trait_id})
