extends Node

signal personality_changed(person_id: String)
signal personality_event(event: Dictionary)
signal incident_changed

const TRAITS := {
    "arena_lover": {"name":"Amante de la arena","description":"Disfruta el combate y resiste mejor la presión del público."},
    "freedom_seeker": {"name":"Busca la libertad","description":"Tolera mal el cautiverio y acumula deseo de escapar."},
    "mentor": {"name":"Mentor","description":"Ayuda a otros durante el entrenamiento y actúa con disciplina."},
    "beast_hunter": {"name":"Cazador de bestias","description":"Se crece ante enemigos brutales y combates difíciles."},
    "ambitious": {"name":"Ambicioso","description":"Exige victorias, fama y oportunidades de ascenso."},
    "loyal": {"name":"Leal","description":"Mantiene la cohesión del ludus incluso durante crisis."},
    "vengeful": {"name":"Vengativo","description":"Recuerda derrotas y castigos durante mucho tiempo."},
    "stoic": {"name":"Estoico","description":"Pierde menos moral ante heridas, derrotas y privaciones."},
    "reckless": {"name":"Temerario","description":"Ataca con mayor ferocidad, pero se expone a heridas."},
    "cunning": {"name":"Astuto","description":"Destaca en espionaje, manipulación y lectura del rival."}
}

var records: Dictionary = {}
var recent_events: Array[Dictionary] = []
var pending_incident: Dictionary = {}
var incident_cooldown: int = 0

func _ready() -> void:
    RosterManager.roster_changed.connect(_ensure_records)
    GameState.day_advanced.connect(_on_day_advanced)
    call_deferred("_ensure_records")

func _on_day_advanced(_day: int) -> void:
    incident_cooldown = maxi(0, incident_cooldown - 1)
    if pending_incident.is_empty() and incident_cooldown <= 0:
        _generate_internal_incident()

func _ensure_records() -> void:
    for person in RosterManager.get_people():
        ensure_record(person.id)

func ensure_record(person_id: String) -> Dictionary:
    if not records.has(person_id):
        records[person_id] = {
            "freedom_desire":0,
            "resentment":0,
            "ambition":0,
            "discipline":50,
            "confidence":50,
            "grudges":[],
            "last_reaction":""
        }
    return records[person_id]

func process_person_day(person, result: Dictionary) -> Dictionary:
    var record := ensure_record(person.id)
    var notes: Array[String] = []
    if person.traits.has("freedom_seeker"):
        var gain := 2 if person.job != "training" else 1
        if person.loyalty < 40:
            gain += 2
        record["freedom_desire"] = clampi(int(record.get("freedom_desire", 0)) + gain, 0, 100)
        person.morale = maxi(0, person.morale - 1)
    if person.traits.has("loyal"):
        person.loyalty = mini(100, person.loyalty + 1)
        record["discipline"] = mini(100, int(record.get("discipline", 50)) + 1)
    if person.traits.has("mentor") and person.job == "training":
        result["training"] = int(result.get("training", 0)) + 2
        person.training += 2
        notes.append("Su experiencia mejora el entrenamiento colectivo.")
    if person.traits.has("ambitious"):
        record["ambition"] = mini(100, int(record.get("ambition", 0)) + 1)
        if person.job == "idle":
            person.morale = maxi(0, person.morale - 2)
    if person.traits.has("stoic"):
        person.morale = mini(100, person.morale + 1)
    if person.traits.has("cunning") and person.job == "espionage":
        result["intel"] = int(result.get("intel", 0)) + 3
    _check_personal_crisis(person, record, notes)
    personality_changed.emit(person.id)
    return {"notes":notes,"freedom_desire":record.get("freedom_desire", 0),"resentment":record.get("resentment", 0)}

func register_combat_result(person, victory: bool, surrendered: bool, injury_severity: int) -> Dictionary:
    var record := ensure_record(person.id)
    var reaction := ""
    if victory:
        record["confidence"] = mini(100, int(record.get("confidence", 50)) + 8)
        record["resentment"] = maxi(0, int(record.get("resentment", 0)) - 3)
        if person.traits.has("arena_lover"):
            person.morale = mini(100, person.morale + 5)
            reaction = "La arena alimenta su entusiasmo."
        elif person.traits.has("ambitious"):
            person.loyalty = mini(100, person.loyalty + 2)
            reaction = "La victoria satisface temporalmente su ambición."
    else:
        record["confidence"] = maxi(0, int(record.get("confidence", 50)) - (4 if person.traits.has("stoic") else 9))
        if person.traits.has("vengeful"):
            record["resentment"] = mini(100, int(record.get("resentment", 0)) + 10)
            reaction = "Jura devolver la humillación sufrida."
        if person.traits.has("ambitious"):
            person.morale = maxi(0, person.morale - 4)
    if surrendered and person.traits.has("arena_lover"):
        person.morale = maxi(0, person.morale - 5)
    if injury_severity > 0 and person.traits.has("stoic"):
        person.morale = mini(100, person.morale + 3)
    record["last_reaction"] = reaction
    var event := {"person_id":person.id,"person_name":person.display_name,"type":"combat_reaction","description":reaction}
    if not reaction.is_empty():
        _push_event(event)
    personality_changed.emit(person.id)
    return event

func get_combat_modifiers(person_id: String, traits: Array[String]) -> Dictionary:
    var record := ensure_record(person_id)
    var result := {"attack":1.0,"defense":1.0,"accuracy":0,"injury_risk":1.0,"surrender":0}
    if traits.has("reckless"):
        result.attack = 1.10
        result.defense = 0.94
        result.injury_risk = 1.20
        result.surrender = -6
    if traits.has("beast_hunter"):
        result.attack = float(result.attack) * 1.05
    if traits.has("cunning"):
        result.accuracy = 5
    if traits.has("stoic"):
        result.surrender = int(result.surrender) - 5
    if int(record.get("confidence", 50)) >= 75:
        result.attack = float(result.attack) * 1.04
    elif int(record.get("confidence", 50)) <= 25:
        result.surrender = int(result.surrender) + 8
    return result

func apply_discipline(person_id: String, action: String) -> Dictionary:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return {}
    var record := ensure_record(person_id)
    var description := ""
    match action:
        "reward":
            if not GameState.spend_denarii(25):
                return {}
            person.morale = mini(100, person.morale + 8)
            person.loyalty = mini(100, person.loyalty + 4)
            record["resentment"] = maxi(0, int(record.get("resentment", 0)) - 8)
            description = "%s recibió una recompensa personal." % person.display_name
        "leniency":
            person.loyalty = mini(100, person.loyalty + 3)
            record["freedom_desire"] = maxi(0, int(record.get("freedom_desire", 0)) - 6)
            description = "%s interpretó la clemencia como una señal de respeto." % person.display_name
        "punishment":
            record["discipline"] = mini(100, int(record.get("discipline", 50)) + 10)
            record["resentment"] = mini(100, int(record.get("resentment", 0)) + (14 if person.traits.has("vengeful") else 8))
            person.morale = maxi(0, person.morale - (5 if person.traits.has("stoic") else 10))
            person.loyalty = maxi(0, person.loyalty - 5)
            description = "%s fue castigado; obedecerá, pero no olvidará." % person.display_name
        _:
            return {}
    var event := {"person_id":person.id,"person_name":person.display_name,"type":"discipline","description":description,"action":action}
    _push_event(event)
    RosterManager.roster_changed.emit()
    personality_changed.emit(person.id)
    return event

func resolve_pending_incident(choice_id: String) -> Dictionary:
    if pending_incident.is_empty():
        return {}
    var incident := pending_incident.duplicate(true)
    var person = RosterManager.get_person(str(incident.get("person_id", "")))
    if person == null:
        pending_incident.clear()
        incident_changed.emit()
        return {}
    var record := ensure_record(person.id)
    var outcome := ""
    match str(incident.get("type", "")):
        "escape_attempt":
            if choice_id == "negotiate":
                if not GameState.spend_denarii(35): return {}
                person.loyalty = mini(100, person.loyalty + 8)
                record["freedom_desire"] = maxi(0, int(record.get("freedom_desire", 0)) - 25)
                outcome = "Se negoció una promesa de mejores condiciones."
            elif choice_id == "guards":
                record["discipline"] = mini(100, int(record.get("discipline", 50)) + 12)
                record["resentment"] = mini(100, int(record.get("resentment", 0)) + 15)
                record["freedom_desire"] = maxi(0, int(record.get("freedom_desire", 0)) - 8)
                outcome = "Los guardias frustraron la fuga, pero aumentó el resentimiento."
            elif choice_id == "release":
                RosterManager.people.erase(person)
                records.erase(person.id)
                outcome = "%s fue liberado y abandonó el ludus." % person.display_name
            else: return {}
        "internal_fight":
            var other = RosterManager.get_person(str(incident.get("other_id", "")))
            if choice_id == "mediate":
                record["resentment"] = maxi(0, int(record.get("resentment", 0)) - 12)
                person.morale = mini(100, person.morale + 3)
                if other != null: other.morale = mini(100, other.morale + 3)
                outcome = "La mediación redujo la tensión entre ambos."
            elif choice_id == "punish_both":
                person.morale = maxi(0, person.morale - 8)
                record["discipline"] = mini(100, int(record.get("discipline", 50)) + 8)
                if other != null: other.morale = maxi(0, other.morale - 8)
                outcome = "Ambos fueron castigados para restaurar el orden."
            else: return {}
        "personal_sabotage":
            if choice_id == "investigate":
                if RosterManager.intelligence_points < 8: return {}
                RosterManager.intelligence_points -= 8
                record["resentment"] = maxi(0, int(record.get("resentment", 0)) - 10)
                outcome = "La investigación reveló el origen del conflicto y evitó nuevas pérdidas."
            elif choice_id == "compensate":
                if not GameState.spend_denarii(40): return {}
                record["resentment"] = maxi(0, int(record.get("resentment", 0)) - 20)
                person.loyalty = mini(100, person.loyalty + 5)
                outcome = "Una compensación personal calmó el conflicto."
            elif choice_id == "punish":
                GameState.food = maxi(0, GameState.food - 5)
                record["discipline"] = mini(100, int(record.get("discipline", 50)) + 10)
                record["resentment"] = mini(100, int(record.get("resentment", 0)) + 12)
                outcome = "El castigo impuso orden, aunque el resentimiento persiste."
            else: return {}
        _:
            return {}
    incident["outcome"] = outcome
    incident["resolved_day"] = GameState.day
    _push_event({"person_id":person.id,"person_name":person.display_name,"type":"incident_resolved","description":outcome})
    pending_incident.clear()
    incident_cooldown = 3
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    incident_changed.emit()
    return incident

func get_record(person_id: String) -> Dictionary:
    return ensure_record(person_id).duplicate(true)

func get_trait_name(trait_id: String) -> String:
    return str(TRAITS.get(trait_id, {}).get("name", trait_id.capitalize()))

func get_trait_description(trait_id: String) -> String:
    return str(TRAITS.get(trait_id, {}).get("description", "Rasgo sin descripción."))

func export_state() -> Dictionary:
    return {"records":records.duplicate(true),"recent_events":recent_events.duplicate(true),"pending_incident":pending_incident.duplicate(true),"incident_cooldown":incident_cooldown}

func import_state(data: Dictionary) -> void:
    records = data.get("records", {}).duplicate(true)
    recent_events.assign(data.get("recent_events", []))
    pending_incident = data.get("pending_incident", {}).duplicate(true)
    incident_cooldown = maxi(0, int(data.get("incident_cooldown", 0)))
    _ensure_records()
    incident_changed.emit()

func _generate_internal_incident() -> void:
    var candidates: Array = []
    for person in RosterManager.get_people():
        var record := ensure_record(person.id)
        var freedom := int(record.get("freedom_desire", 0))
        var resentment := int(record.get("resentment", 0))
        if freedom >= 70 or resentment >= 65:
            candidates.append({"person":person,"freedom":freedom,"resentment":resentment})
    if candidates.is_empty():
        return
    var selected: Dictionary = candidates[randi_range(0, candidates.size() - 1)]
    var person = selected.person
    var event_type := "escape_attempt" if int(selected.freedom) >= int(selected.resentment) else ("personal_sabotage" if randf() < 0.55 else "internal_fight")
    pending_incident = {"type":event_type,"person_id":person.id,"person_name":person.display_name,"day":GameState.day}
    if event_type == "internal_fight":
        for other in RosterManager.get_people():
            if other.id != person.id:
                pending_incident["other_id"] = other.id
                pending_incident["other_name"] = other.display_name
                break
    _push_event({"person_id":person.id,"person_name":person.display_name,"type":event_type,"description":_incident_description(pending_incident)})
    incident_changed.emit()

func _incident_description(incident: Dictionary) -> String:
    match str(incident.get("type", "")):
        "escape_attempt": return "%s fue descubierto preparando una fuga." % incident.get("person_name", "Un miembro")
        "internal_fight": return "%s inició una pelea con %s." % [incident.get("person_name", "Un miembro"), incident.get("other_name", "otro miembro")]
        "personal_sabotage": return "Se sospecha que %s dañó suministros del ludus." % incident.get("person_name", "un miembro")
        _: return "Se produjo un conflicto interno."

func _check_personal_crisis(person, record: Dictionary, notes: Array[String]) -> void:
    if int(record.get("freedom_desire", 0)) >= 85 and person.loyalty <= 30:
        notes.append("Considera seriamente escapar del ludus.")
        record["last_reaction"] = "Desea escapar."
    if int(record.get("resentment", 0)) >= 80:
        notes.append("Su resentimiento puede transformarse en sabotaje o violencia.")

func _push_event(event: Dictionary) -> void:
    recent_events.push_front(event.duplicate(true))
    if recent_events.size() > 40:
        recent_events.resize(40)
    personality_event.emit(event)
