extends Node

signal injury_state_changed(person_id: String)
signal scar_added(person_id: String, scar: Dictionary)
signal recovery_reduced(person_id: String, weeks: int, source: String)

const MAX_SCARS := 8

func _ready() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    GameState.week_advanced.connect(_on_week_advanced)
    SaveManager.load_completed.connect(func(_path: String): _sanitize_all())
    RosterManager.roster_changed.connect(_sanitize_all)
    call_deferred("_sanitize_all")

func get_active_injury(person_id: String) -> Dictionary:
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    return record.get("active_injury", {}).duplicate(true)

func get_scars(person_id: String) -> Array[Dictionary]:
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    var result: Array[Dictionary] = []
    result.assign(record.get("scars", []))
    return result.duplicate(true)

func get_summary(person_id: String) -> Dictionary:
    var person = RosterManager.get_person(person_id)
    return {
        "active": get_active_injury(person_id),
        "scars": get_scars(person_id),
        "available_for_combat": person != null and person.is_available_for_combat()
    }

func reduce_recovery(person_id: String, weeks: int, source: String = "tratamiento") -> int:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator" or person.injury_days <= 0:
        return 0
    var reduction := mini(person.injury_days, maxi(0, weeks))
    if reduction <= 0:
        return 0
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    var active: Dictionary = record.get("active_injury", {})
    if active.is_empty():
        active = {
            "name": person.injury_name,
            "severity": clampi(person.injury_severity, 1, 3),
            "started_week": GameState.get_week(),
            "recovery_weeks": person.injury_days,
            "event_name": "Tratamiento médico"
        }
    person.injury_days = maxi(0, person.injury_days - reduction)
    active["recovery_weeks"] = person.injury_days
    record["active_injury"] = active
    recovery_reduced.emit(person_id, reduction, source)
    if person.injury_days <= 0:
        person.injury_severity = 0
        person.injury_name = ""
        _complete_recovery(person, record, active)
    else:
        injury_state_changed.emit(person_id)
        GladiatorProgressionManager.progression_changed.emit()
    RosterManager.roster_changed.emit()
    return reduction

func _on_combat_finished(result: Dictionary) -> void:
    var person_id := str(result.get("fighter_id", ""))
    var person = RosterManager.get_person(person_id)
    if person == null or person.injury_days <= 0:
        return
    var record := GladiatorProgressionManager.ensure_record(person_id)
    record["active_injury"] = {
        "name": person.injury_name,
        "severity": clampi(person.injury_severity, 1, 3),
        "started_week": GameState.get_week(),
        "recovery_weeks": person.injury_days,
        "event_name": str(result.get("event_name", "Arena"))
    }
    injury_state_changed.emit(person_id)
    GladiatorProgressionManager.progression_changed.emit()

func _on_week_advanced(_week: int) -> void:
    for person in RosterManager.get_people():
        if person.role != "gladiator":
            continue
        var record := GladiatorProgressionManager.ensure_record(person.id)
        _sanitize_record(record)
        var active: Dictionary = record.get("active_injury", {})
        if active.is_empty():
            continue
        if person.injury_days > 0:
            active["recovery_weeks"] = person.injury_days
            record["active_injury"] = active
            injury_state_changed.emit(person.id)
            continue
        _complete_recovery(person, record, active)

func _complete_recovery(person, record: Dictionary, injury: Dictionary) -> void:
    record["active_injury"] = {}
    var severity := int(injury.get("severity", 1))
    var creates_scar := severity >= 3
    if severity == 2:
        var seed_text := "%s|%s|%d" % [person.id, injury.get("name", "Herida"), int(injury.get("started_week", 1))]
        creates_scar = absi(hash(seed_text)) % 100 < 35
    if creates_scar:
        _add_scar(person, record, injury)
    GladiatorCareerJournalController.add_event(person.id, "recovery", "Recuperación completada", "%s se recuperó de %s.%s" % [
        person.display_name,
        injury.get("name", "una herida"),
        " La lesión dejó una secuela permanente." if creates_scar else ""
    ], {"severity": severity, "scar": creates_scar})
    injury_state_changed.emit(person.id)
    GladiatorProgressionManager.progression_changed.emit()

func _add_scar(person, record: Dictionary, injury: Dictionary) -> void:
    var scars: Array = record.get("scars", [])
    var penalty := _penalty_for_injury(str(injury.get("name", "Herida")), int(injury.get("severity", 1)))
    var scar := {
        "name": _scar_name(str(injury.get("name", "Herida"))),
        "source_injury": str(injury.get("name", "Herida")),
        "week": GameState.get_week(),
        "penalty": penalty.duplicate(true)
    }
    scars.push_front(scar)
    if scars.size() > MAX_SCARS:
        scars.resize(MAX_SCARS)
    record["scars"] = scars
    person.apply_growth(penalty)
    GladiatorCareerJournalController.add_event(person.id, "scar", "Cicatriz permanente", "%s conserva %s como recuerdo de la arena." % [person.display_name, scar.name], scar)
    scar_added.emit(person.id, scar.duplicate(true))

func _penalty_for_injury(injury_name: String, severity: int) -> Dictionary:
    var lowered := injury_name.to_lower()
    if "fractura" in lowered or "luxación" in lowered:
        return {"agility": -1}
    if "desgarro" in lowered or "trauma" in lowered:
        return {"endurance": -1}
    if severity >= 3:
        return {"health": -5}
    return {"technique": -1}

func _scar_name(injury_name: String) -> String:
    var lowered := injury_name.to_lower()
    if "bestia" in lowered:
        return "cicatriz de garras"
    if "fractura" in lowered:
        return "secuela de fractura"
    if "trauma" in lowered:
        return "dolor persistente"
    return "cicatriz de combate"

func _sanitize_all() -> void:
    for person in RosterManager.get_people():
        if person.role == "gladiator":
            _sanitize_record(GladiatorProgressionManager.ensure_record(person.id))

func _sanitize_record(record: Dictionary) -> void:
    var active = record.get("active_injury", {})
    record["active_injury"] = active.duplicate(true) if active is Dictionary else {}
    var clean_scars: Array[Dictionary] = []
    var raw_scars = record.get("scars", [])
    if raw_scars is Array:
        for raw in raw_scars:
            if not raw is Dictionary or clean_scars.size() >= MAX_SCARS:
                continue
            clean_scars.append({
                "name": str(raw.get("name", "cicatriz de combate")),
                "source_injury": str(raw.get("source_injury", "Herida")),
                "week": maxi(1, int(raw.get("week", 1))),
                "penalty": raw.get("penalty", {}).duplicate(true) if raw.get("penalty", {}) is Dictionary else {}
            })
    record["scars"] = clean_scars
