extends Node

signal relationships_changed
signal relationship_event(event: Dictionary)

var relationships: Dictionary = {}
var recent_events: Array[Dictionary] = []
var day_serial: int = 0

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
            relation["respect"] = min(100, int(relation.get("respect", 0)) + 3)
            a.morale = mini(100, a.morale + 2)
            b.morale = mini(100, b.morale + 2)
        _:
            return {}
    relation["state"] = _derive_state(relation)
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

func get_relationship(a_id: String, b_id: String) -> Dictionary:
    return ensure_relationship(a_id, b_id).duplicate(true)

func get_person_relationships(person_id: String) -> Array:
    var result: Array = []
    for relation in relationships.values():
        if str(relation.get("a_id", "")) == person_id or str(relation.get("b_id", "")) == person_id:
            result.append(relation.duplicate(true))
    return result

func get_combat_morale_bonus(person_id: String) -> int:
    var bonus := 0
    for relation in get_person_relationships(person_id):
        if str(relation.get("state", "")) == "amistad": bonus += 1
        elif str(relation.get("state", "")) == "rivalidad": bonus += 1
        elif str(relation.get("state", "")) == "enemistad": bonus -= 2
    return clampi(bonus, -6, 6)

func export_state() -> Dictionary:
    return {"relationships": relationships.duplicate(true), "recent_events": recent_events.duplicate(true), "day_serial": day_serial}

func import_state(data: Dictionary) -> void:
    relationships = data.get("relationships", {}).duplicate(true)
    recent_events.assign(data.get("recent_events", []))
    day_serial = maxi(0, int(data.get("day_serial", 0)))
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
            stored["respect"] = min(100, int(stored.get("respect", 0)) + 3)
            if int(stored.get("jealousy", 0)) > 20:
                stored["jealousy"] = min(100, int(stored.get("jealousy", 0)) + 2)
        else:
            stored["affinity"] = clampi(int(stored.get("affinity", 0)) + (2 if int(stored.get("affinity", 0)) > 20 else 0), -100, 100)
        stored["state"] = _derive_state(stored)
    relationships_changed.emit()

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
