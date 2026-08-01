extends Node

signal training_focus_changed(person_id: String, focus_id: String)
signal training_completed(person_id: String, result: Dictionary)

const FOCUSES := {
    "balanced": {"name":"Formación equilibrada", "attribute":"", "description":"Reparte la preparación sin forzar un atributo concreto."},
    "strength": {"name":"Fuerza", "attribute":"strength", "description":"Potencia el daño y los trabajos físicos."},
    "agility": {"name":"Agilidad", "attribute":"agility", "description":"Mejora precisión, evasión y energía."},
    "endurance": {"name":"Resistencia", "attribute":"endurance", "description":"Mejora vida, defensa y recuperación en combate."},
    "technique": {"name":"Técnica", "attribute":"technique", "description":"Mejora ataque, defensa y uso de habilidades."},
    "specialization": {"name":"Dominio de especialización", "attribute":"", "description":"Concentra la semana en dominar la especialización elegida."}
}

const ATTRIBUTE_THRESHOLD := 100

func _ready() -> void:
    GameState.week_advanced.connect(func(week: int): call_deferred("process_week", week))
    RosterManager.roster_changed.connect(_ensure_records)
    SaveManager.load_completed.connect(func(_path: String): _ensure_records())
    call_deferred("_ensure_records")

func get_focus_ids() -> Array[String]:
    var result: Array[String] = []
    for focus_id in FOCUSES.keys():
        result.append(str(focus_id))
    return result

func get_focus_data(focus_id: String) -> Dictionary:
    return FOCUSES.get(focus_id, FOCUSES["balanced"]).duplicate(true)

func get_focus(person_id: String) -> String:
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    return str(record.get("training_focus", "balanced"))

func set_focus(person_id: String, focus_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator" or not FOCUSES.has(focus_id):
        return false
    if focus_id == "specialization" and not SpecializationMasteryController.has_selected_specialization(person_id):
        return false
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    record["training_focus"] = focus_id
    training_focus_changed.emit(person_id, focus_id)
    GladiatorProgressionManager.progression_changed.emit()
    return true

func get_preview(person_id: String) -> Dictionary:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        return {}
    var focus_id := get_focus(person_id)
    var gain := _calculate_gain(person)
    var risk := _injury_risk(person)
    return {
        "focus_id": focus_id,
        "focus_name": get_focus_data(focus_id).get("name", focus_id),
        "weekly_gain": gain,
        "fatigue_gain": 7,
        "injury_risk": risk,
        "assigned": person.job == "training",
        "available": person.injury_days <= 0,
        "progress": _focus_progress(GladiatorProgressionManager.ensure_record(person_id), focus_id)
    }

func process_week(week: int) -> void:
    var changed := false
    for person in RosterManager.get_people():
        if person.role != "gladiator" or person.job != "training" or person.injury_days > 0:
            continue
        var record := GladiatorProgressionManager.ensure_record(person.id)
        _sanitize_record(record)
        if int(record.get("last_individual_training_week", 0)) >= week:
            continue
        var result := _apply_training(person, record, week)
        record["last_individual_training_week"] = week
        record["training_sessions"] = int(record.get("training_sessions", 0)) + 1
        training_completed.emit(person.id, result)
        GladiatorCareerJournalController.add_event(person.id, "training", "Entrenamiento individual", str(result.get("summary", "")), result)
        changed = true
    if changed:
        RosterManager.roster_changed.emit()
        GladiatorProgressionManager.progression_changed.emit()

func _apply_training(person, record: Dictionary, week: int) -> Dictionary:
    var focus_id := str(record.get("training_focus", "balanced"))
    var gain := _calculate_gain(person)
    var growth := {}
    var mastery_gain := 0
    var progress_before := _focus_progress(record, focus_id)

    if focus_id == "specialization":
        mastery_gain = SpecializationMasteryController.register_training_use(person.id)
    elif focus_id == "balanced":
        var balanced_progress: Dictionary = record.get("balanced_training_progress", {})
        var attributes := ["strength", "agility", "endurance", "technique"]
        var chosen := attributes[(week + absi(hash(person.id))) % attributes.size()]
        balanced_progress[chosen] = int(balanced_progress.get(chosen, 0)) + gain
        if int(balanced_progress[chosen]) >= ATTRIBUTE_THRESHOLD:
            balanced_progress[chosen] = int(balanced_progress[chosen]) - ATTRIBUTE_THRESHOLD
            growth[chosen] = 1
        record["balanced_training_progress"] = balanced_progress
    else:
        var key := "%s_training_progress" % focus_id
        record[key] = int(record.get(key, 0)) + gain
        if int(record[key]) >= ATTRIBUTE_THRESHOLD:
            record[key] = int(record[key]) - ATTRIBUTE_THRESHOLD
            growth[focus_id] = 1

    if not growth.is_empty():
        person.apply_growth(growth)

    var injury := ""
    var risk := _injury_risk(person)
    var roll := absi(hash("training|%s|%d|%s" % [person.id, week, focus_id])) % 100 + 1
    if risk > 0 and roll <= risk:
        var severity := 2 if person.fatigue >= 85 else 1
        injury = "Sobrecarga muscular" if severity == 1 else "Desgarro por sobreentrenamiento"
        person.apply_injury(injury, severity, severity)

    var progress_after := _focus_progress(record, focus_id)
    var summary := "%s completó %s: +%d progreso" % [person.display_name, str(get_focus_data(focus_id).get("name", focus_id)), gain]
    if mastery_gain > 0:
        summary += ", +%d%% de dominio" % mastery_gain
    if not growth.is_empty():
        summary += ", mejora permanente: %s +1" % str(growth.keys()[0]).capitalize()
    if not injury.is_empty():
        summary += ". Sufrió %s" % injury
    return {
        "week": week,
        "focus_id": focus_id,
        "gain": gain,
        "progress_before": progress_before,
        "progress_after": progress_after,
        "growth": growth,
        "mastery_gain": mastery_gain,
        "injury": injury,
        "injury_risk": risk,
        "summary": summary
    }

func _calculate_gain(person) -> int:
    var base := 6 + floori(float(person.endurance + person.intelligence) / 4.0)
    return maxi(1, int(round(float(base) * EstateManager.get_training_multiplier() * EventManager.get_training_multiplier())))

func _injury_risk(person) -> int:
    if person.fatigue < 60:
        return 0
    return clampi(5 + (person.fatigue - 60) * 2 - person.endurance, 0, 55)

func _focus_progress(record: Dictionary, focus_id: String) -> int:
    if focus_id == "specialization":
        return int(record.get("specialization_progress", 0))
    if focus_id == "balanced":
        var values: Dictionary = record.get("balanced_training_progress", {})
        var total := 0
        for value in values.values():
            total += int(value)
        return total
    return int(record.get("%s_training_progress" % focus_id, 0))

func _ensure_records() -> void:
    for person in RosterManager.get_people():
        if person.role == "gladiator":
            _sanitize_record(GladiatorProgressionManager.ensure_record(person.id))

func _sanitize_record(record: Dictionary) -> void:
    var focus_id := str(record.get("training_focus", "balanced"))
    if not FOCUSES.has(focus_id):
        focus_id = "balanced"
    record["training_focus"] = focus_id
    record["training_sessions"] = maxi(0, int(record.get("training_sessions", 0)))
    record["last_individual_training_week"] = maxi(0, int(record.get("last_individual_training_week", 0)))
    for attribute in ["strength", "agility", "endurance", "technique"]:
        var key := "%s_training_progress" % attribute
        record[key] = clampi(int(record.get(key, 0)), 0, ATTRIBUTE_THRESHOLD - 1)
    var balanced: Dictionary = record.get("balanced_training_progress", {}) if record.get("balanced_training_progress", {}) is Dictionary else {}
    var clean_balanced := {}
    for attribute in ["strength", "agility", "endurance", "technique"]:
        clean_balanced[attribute] = clampi(int(balanced.get(attribute, 0)), 0, ATTRIBUTE_THRESHOLD - 1)
    record["balanced_training_progress"] = clean_balanced
