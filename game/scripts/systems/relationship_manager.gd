extends Node

signal relationships_changed
signal relationship_event(event: Dictionary)
signal social_incident_available(incident: Dictionary)
signal social_incident_resolved(result: Dictionary)

var relationships: Dictionary = {}
var recent_events: Array[Dictionary] = []
var pending_incident: Dictionary = {}
var incident_cooldown: int = 0
var day_serial: int = 0
var incident_serial: int = 0

func _ready() -> void:
    RosterManager.roster_changed.connect(_ensure_all_pairs)
    CombatManager.combat_finished.connect(_on_combat_finished)
    call_deferred("_ensure_all_pairs")

func _pair_key(a_id: String, b_id: String) -> String:
    return "%s|%s" % ([a_id, b_id] if a_id < b_id else [b_id, a_id])

func _ensure_all_pairs() -> void:
    var people := RosterManager.get_people()
    for i in range(people.size()):
        for j in range(i + 1, people.size()):
            ensure_relationship(people[i].id, people[j].id)

func ensure_relationship(a_id: String, b_id: String) -> Dictionary:
    if a_id == b_id:
        return {}
    var key := _pair_key(a_id, b_id)
    if not relationships.has(key):
        relationships[key] = {
            "a_id": a_id,
            "b_id": b_id,
            "affinity": 0,
            "respect": 0,
            "rivalry": 0,
            "jealousy": 0,
            "mentorship": 0,
            "state": "neutral",
            "last_change": ""
        }
    return relationships[key]

func process_day(totals: Dictionary) -> Array:
    _ensure_all_pairs()
    day_serial += 1
    incident_cooldown = maxi(0, incident_cooldown - 1)
    var events: Array = []
    for relation in relationships.values():
        var a = RosterManager.get_person(str(relation.get("a_id", "")))
        var b = RosterManager.get_person(str(relation.get("b_id", "")))
        if a == null or b == null:
            continue
        var changed := false
        if a.job == b.job and a.job != "idle":
            relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 1, -100, 100)
            relation["respect"] = clampi(int(relation.get("respect", 0)) + 1, -100, 100)
            changed = true
        if a.job == "training" and b.job == "training":
            relation["mentorship"] = clampi(int(relation.get("mentorship", 0)) + (2 if a.traits.has("mentor") or b.traits.has("mentor") else 1), 0, 100)
            totals["training"] = int(totals.get("training", 0)) + 1
            changed = true
        var a_progress := GladiatorProgressionManager.get_record(a.id) if a.role == "gladiator" else {}
        var b_progress := GladiatorProgressionManager.get_record(b.id) if b.role == "gladiator" else {}
        var fame_gap := abs(int(a_progress.get("fame", 0)) - int(b_progress.get("fame", 0)))
        if fame_gap >= 20 and (a.traits.has("ambitious") or b.traits.has("ambitious")):
            relation["jealousy"] = clampi(int(relation.get("jealousy", 0)) + 1, 0, 100)
            changed = true
        if int(relation.get("affinity", 0)) >= 45:
            a.morale = mini(100, a.morale + 1)
            b.morale = mini(100, b.morale + 1)
        if int(relation.get("rivalry", 0)) >= 60:
            a.fatigue = mini(100, a.fatigue + 1)
            b.fatigue = mini(100, b.fatigue + 1)
        var previous_state := str(relation.get("state", "neutral"))
        relation["state"] = _derive_state(relation)
        if previous_state != relation["state"]:
            var event := _build_state_event(a, b, relation)
            events.append(event)
            _push_event(event)
            changed = true
        if changed:
            relation["last_change"] = "Día %d" % GameState.day
    _try_generate_social_incident()
    if not events.is_empty() or day_serial % 3 == 0:
        relationships_changed.emit()
    return events

func register_interaction(a_id: String, b_id: String, interaction: String) -> Dictionary:
    var relation := ensure_relationship(a_id, b_id)
    if relation.is_empty():
        return {}
    var a = RosterManager.get_person(a_id)
    var b = RosterManager.get_person(b_id)
    if a == null or b == null:
        return {}
    match interaction:
        "train_together":
            relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 5, -100, 100)
            relation["respect"] = clampi(int(relation.get("respect", 0)) + 4, -100, 100)
            a.fatigue = mini(100, a.fatigue + 4)
            b.fatigue = mini(100, b.fatigue + 4)
        "mediate":
            if not GameState.spend_denarii(15):
                return {}
            relation["rivalry"] = maxi(0, int(relation.get("rivalry", 0)) - 12)
            relation["jealousy"] = maxi(0, int(relation.get("jealousy", 0)) - 8)
            relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 3, -100, 100)
        "encourage_rivalry":
            relation["rivalry"] = mini(100, int(relation.get("rivalry", 0)) + 12)
            relation["respect"] = mini(100, int(relation.get("respect", 0)) + 3)
            a.morale = mini(100, a.morale + 2)
            b.morale = mini(100, b.morale + 2)
        _:
            return {}
    relation["state"] = _derive_state(relation)
    relation["last_change"] = "Día %d" % GameState.day
    var event := {
        "type": "relationship_interaction",
        "a_id": a_id,
        "b_id": b_id,
        "description": "%s y %s: %s." % [a.display_name, b.display_name, interaction]
    }
    _push_event(event)
    RosterManager.roster_changed.emit()
    relationships_changed.emit()
    return event

func resolve_social_incident(choice_id: String) -> Dictionary:
    if pending_incident.is_empty():
        return {}
    var relation := ensure_relationship(str(pending_incident.get("a_id", "")), str(pending_incident.get("b_id", "")))
    var a = RosterManager.get_person(str(pending_incident.get("a_id", "")))
    var b = RosterManager.get_person(str(pending_incident.get("b_id", "")))
    if relation.is_empty() or a == null or b == null:
        pending_incident.clear()
        relationships_changed.emit()
        return {}
    var incident_type := str(pending_incident.get("type", ""))
    var description := ""
    match incident_type:
        "jealousy":
            match choice_id:
                "recognize_both":
                    if not GameState.spend_denarii(30): return {}
                    relation["jealousy"] = maxi(0, int(relation.get("jealousy", 0)) - 18)
                    relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 6, -100, 100)
                    a.morale = mini(100, a.morale + 5)
                    b.morale = mini(100, b.morale + 5)
                    description = "El reconocimiento compartido redujo los celos."
                "choose_favorite":
                    relation["jealousy"] = mini(100, int(relation.get("jealousy", 0)) + 15)
                    relation["rivalry"] = mini(100, int(relation.get("rivalry", 0)) + 10)
                    a.morale = mini(100, a.morale + 6)
                    b.morale = maxi(0, b.morale - 8)
                    description = "Elegir un favorito intensificó la rivalidad."
                "ignore":
                    relation["jealousy"] = mini(100, int(relation.get("jealousy", 0)) + 8)
                    description = "La tensión continuó creciendo sin intervención."
                _: return {}
        "mentorship":
            match choice_id:
                "formalize":
                    relation["mentorship"] = mini(100, int(relation.get("mentorship", 0)) + 20)
                    relation["respect"] = mini(100, int(relation.get("respect", 0)) + 10)
                    a.training += 8
                    b.training += 8
                    description = "La mentoría fue formalizada y mejoró el entrenamiento."
                "separate":
                    relation["mentorship"] = maxi(0, int(relation.get("mentorship", 0)) - 15)
                    relation["affinity"] = clampi(int(relation.get("affinity", 0)) - 5, -100, 100)
                    description = "La separación debilitó el vínculo de aprendizaje."
                _: return {}
        "friendship":
            match choice_id:
                "celebrate":
                    if not GameState.spend_denarii(20): return {}
                    relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 10, -100, 100)
                    a.morale = mini(100, a.morale + 7)
                    b.morale = mini(100, b.morale + 7)
                    description = "La celebración fortaleció la amistad."
                "exploit":
                    relation["respect"] = maxi(-100, int(relation.get("respect", 0)) - 8)
                    relation["affinity"] = clampi(int(relation.get("affinity", 0)) - 6, -100, 100)
                    GameState.denarii += 25
                    description = "El ludus explotó el vínculo y obtuvo ingresos, pero perdió respeto."
                _: return {}
        "protection":
            match choice_id:
                "honor_protector":
                    relation["respect"] = mini(100, int(relation.get("respect", 0)) + 15)
                    relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 8, -100, 100)
                    a.loyalty = mini(100, a.loyalty + 4)
                    b.loyalty = mini(100, b.loyalty + 4)
                    GameState.reputation += 2
                    description = "El acto de protección fue honrado públicamente."
                "punish_interference":
                    relation["affinity"] = clampi(int(relation.get("affinity", 0)) - 12, -100, 100)
                    relation["rivalry"] = mini(100, int(relation.get("rivalry", 0)) + 8)
                    a.morale = maxi(0, a.morale - 5)
                    description = "Castigar la intervención dañó profundamente el vínculo."
                _: return {}
        "betrayal":
            match choice_id:
                "reconcile":
                    if not GameState.spend_denarii(35): return {}
                    relation["rivalry"] = maxi(0, int(relation.get("rivalry", 0)) - 20)
                    relation["jealousy"] = maxi(0, int(relation.get("jealousy", 0)) - 15)
                    relation["affinity"] = clampi(int(relation.get("affinity", 0)) + 8, -100, 100)
                    description = "La reconciliación evitó una ruptura definitiva."
                "sanction":
                    relation["rivalry"] = mini(100, int(relation.get("rivalry", 0)) + 10)
                    relation["respect"] = maxi(-100, int(relation.get("respect", 0)) - 12)
                    b.loyalty = maxi(0, b.loyalty - 6)
                    description = "La sanción impuso orden, pero consolidó la enemistad."
                _: return {}
        _:
            return {}
    relation["state"] = _derive_state(relation)
    relation["last_change"] = "Día %d" % GameState.day
    var result := pending_incident.duplicate(true)
    result["choice_id"] = choice_id
    result["description"] = description
    result["resolved_day"] = GameState.day
    pending_incident.clear()
    incident_cooldown = 4
    _push_event(result)
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    relationships_changed.emit()
    social_incident_resolved.emit(result)
    return result

func get_relationship(a_id: String, b_id: String) -> Dictionary:
    return ensure_relationship(a_id, b_id).duplicate(true)

func get_person_relationships(person_id: String) -> Array:
    var result: Array = []
    for relation in relationships.values():
        if str(relation.get("a_id", "")) == person_id or str(relation.get("b_id", "")) == person_id:
            result.append(relation.duplicate(true))
    return result

func get_pending_incident() -> Dictionary:
    return pending_incident.duplicate(true)

func get_combat_morale_bonus(person_id: String) -> int:
    var bonus := 0
    for relation in get_person_relationships(person_id):
        if str(relation.get("state", "")) == "amistad": bonus += 1
        elif str(relation.get("state", "")) == "rivalidad": bonus += 1
        elif str(relation.get("state", "")) == "enemistad": bonus -= 2
    return clampi(bonus, -6, 6)

func export_state() -> Dictionary:
    return {
        "relationships": relationships.duplicate(true),
        "recent_events": recent_events.duplicate(true),
        "pending_incident": pending_incident.duplicate(true),
        "incident_cooldown": incident_cooldown,
        "day_serial": day_serial,
        "incident_serial": incident_serial
    }

func import_state(data: Dictionary) -> void:
    relationships = data.get("relationships", {}).duplicate(true)
    recent_events.assign(data.get("recent_events", []))
    pending_incident = data.get("pending_incident", {}).duplicate(true)
    incident_cooldown = maxi(0, int(data.get("incident_cooldown", 0)))
    day_serial = maxi(0, int(data.get("day_serial", 0)))
    incident_serial = maxi(0, int(data.get("incident_serial", 0)))
    _ensure_all_pairs()
    relationships_changed.emit()

func _on_combat_finished(result: Dictionary) -> void:
    var fighter_id := str(result.get("fighter_id", ""))
    if fighter_id.is_empty():
        return
    for relation in get_person_relationships(fighter_id):
        var other_id := str(relation.get("b_id", "")) if str(relation.get("a_id", "")) == fighter_id else str(relation.get("a_id", ""))
        var stored := ensure_relationship(fighter_id, other_id)
        if bool(result.get("victory", false)):
            stored["respect"] = mini(100, int(stored.get("respect", 0)) + 3)
            if int(stored.get("jealousy", 0)) > 20:
                stored["jealousy"] = mini(100, int(stored.get("jealousy", 0)) + 2)
        else:
            stored["affinity"] = clampi(int(stored.get("affinity", 0)) + (2 if int(stored.get("affinity", 0)) > 20 else 0), -100, 100)
        stored["state"] = _derive_state(stored)
    relationships_changed.emit()

func _try_generate_social_incident() -> void:
    if not pending_incident.is_empty() or incident_cooldown > 0:
        return
    var candidates: Array[Dictionary] = []
    for relation in relationships.values():
        var state := str(relation.get("state", "neutral"))
        if int(relation.get("jealousy", 0)) >= 55:
            candidates.append(_make_incident("jealousy", relation, "Los celos amenazan con dividir el ludus.", ["recognize_both", "choose_favorite", "ignore"]))
        elif state == "mentoría" and int(relation.get("mentorship", 0)) >= 55:
            candidates.append(_make_incident("mentorship", relation, "Una relación de mentoría reclama reconocimiento formal.", ["formalize", "separate"]))
        elif state == "amistad" and int(relation.get("affinity", 0)) >= 60:
            candidates.append(_make_incident("friendship", relation, "Una amistad se ha vuelto visible para toda la casa.", ["celebrate", "exploit"]))
        elif state == "enemistad":
            candidates.append(_make_incident("betrayal", relation, "Una enemistad amenaza con convertirse en traición.", ["reconcile", "sanction"]))
        elif int(relation.get("respect", 0)) >= 60 and int(relation.get("affinity", 0)) >= 25:
            candidates.append(_make_incident("protection", relation, "Uno de ellos protegió al otro durante una crisis.", ["honor_protector", "punish_interference"]))
    if candidates.is_empty() or randf() > 0.28:
        return
    pending_incident = candidates[randi_range(0, candidates.size() - 1)]
    social_incident_available.emit(pending_incident.duplicate(true))
    relationships_changed.emit()

func _make_incident(type_id: String, relation: Dictionary, text: String, choices: Array) -> Dictionary:
    incident_serial += 1
    var a = RosterManager.get_person(str(relation.get("a_id", "")))
    var b = RosterManager.get_person(str(relation.get("b_id", "")))
    return {
        "id": "social_%d" % incident_serial,
        "type": type_id,
        "a_id": relation.get("a_id", ""),
        "b_id": relation.get("b_id", ""),
        "a_name": a.display_name if a != null else "Desconocido",
        "b_name": b.display_name if b != null else "Desconocido",
        "title": "Incidente social",
        "description": text,
        "choices": choices,
        "created_day": GameState.day
    }

func get_choice_label(choice_id: String) -> String:
    var labels := {
        "recognize_both":"Reconocer a ambos (30 denarios)",
        "choose_favorite":"Elegir un favorito",
        "ignore":"Ignorar la tensión",
        "formalize":"Formalizar mentoría",
        "separate":"Separarlos",
        "celebrate":"Celebrar el vínculo (20 denarios)",
        "exploit":"Explotar su popularidad",
        "honor_protector":"Honrar al protector",
        "punish_interference":"Castigar la intervención",
        "reconcile":"Financiar reconciliación (35 denarios)",
        "sanction":"Sancionar la traición"
    }
    return str(labels.get(choice_id, choice_id.capitalize()))

func _derive_state(relation: Dictionary) -> String:
    if int(relation.get("rivalry", 0)) >= 70 and int(relation.get("affinity", 0)) <= -25:
        return "enemistad"
    if int(relation.get("mentorship", 0)) >= 45 and int(relation.get("respect", 0)) >= 25:
        return "mentoría"
    if int(relation.get("affinity", 0)) >= 45:
        return "amistad"
    if int(relation.get("rivalry", 0)) >= 40 or int(relation.get("jealousy", 0)) >= 50:
        return "rivalidad"
    if int(relation.get("respect", 0)) >= 35:
        return "respeto"
    return "neutral"

func _build_state_event(a, b, relation: Dictionary) -> Dictionary:
    var state := str(relation.get("state", "neutral"))
    return {
        "type": "relationship_state",
        "a_id": a.id,
        "b_id": b.id,
        "state": state,
        "description": "%s y %s desarrollaron una relación de %s." % [a.display_name, b.display_name, state]
    }

func _push_event(event: Dictionary) -> void:
    recent_events.push_front(event.duplicate(true))
    if recent_events.size() > 50:
        recent_events.resize(50)
    relationship_event.emit(event)
