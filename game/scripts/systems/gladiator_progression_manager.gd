extends Node

signal progression_changed
signal gladiator_leveled(person_id: String, new_level: int)
signal specialization_changed(person_id: String, specialization: String)

const SPECIALIZATIONS := {
    "balanced": {"name":"Versátil","attack":1.0,"defense":1.0,"health":1.0,"energy":1.0},
    "murmillo": {"name":"Murmillo","attack":1.08,"defense":1.14,"health":1.10,"energy":0.94},
    "retiarius": {"name":"Retiarius","attack":1.10,"defense":0.90,"health":0.94,"energy":1.16},
    "secutor": {"name":"Secutor","attack":1.14,"defense":1.05,"health":1.02,"energy":0.98},
    "thraex": {"name":"Thraex","attack":1.06,"defense":1.08,"health":0.98,"energy":1.08}
}

var records: Dictionary = {}

func ensure_record(person_id: String) -> Dictionary:
    if not records.has(person_id):
        records[person_id] = {
            "level":1,
            "experience":0,
            "specialization":"balanced",
            "fame":0,
            "wins":0,
            "losses":0,
            "age_days":0,
            "career_state":"activo",
            "technique_points":0
        }
    return records[person_id]

func register_combat_result(person_id: String, victory: bool, rounds: int, difficulty: int = 1) -> Dictionary:
    var record := ensure_record(person_id)
    var experience_gain := maxi(8, rounds * 2 + difficulty * 8)
    var fame_gain := difficulty * (5 if victory else 1)
    if victory:
        experience_gain += 15
        record["wins"] = int(record.get("wins", 0)) + 1
    else:
        record["losses"] = int(record.get("losses", 0)) + 1
    record["experience"] = int(record.get("experience", 0)) + experience_gain
    record["fame"] = maxi(0, int(record.get("fame", 0)) + fame_gain)
    _resolve_level_ups(person_id, record)
    progression_changed.emit()
    return {"experience":experience_gain,"fame":fame_gain,"level":record.get("level", 1)}

func process_day() -> void:
    var changed := false
    for person in RosterManager.get_people():
        if person.role != "gladiator":
            continue
        var record := ensure_record(person.id)
        record["age_days"] = int(record.get("age_days", 0)) + 1
        var age_days := int(record.get("age_days", 0))
        if age_days >= 360:
            record["career_state"] = "veterano"
        if age_days >= 540:
            record["career_state"] = "declive"
        changed = true
    if changed:
        progression_changed.emit()

func set_specialization(person_id: String, specialization: String) -> bool:
    if not SPECIALIZATIONS.has(specialization):
        return false
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        return false
    var record := ensure_record(person_id)
    if int(record.get("level", 1)) < 3 and specialization != "balanced":
        return false
    record["specialization"] = specialization
    specialization_changed.emit(person_id, specialization)
    progression_changed.emit()
    return true

func get_record(person_id: String) -> Dictionary:
    return ensure_record(person_id).duplicate(true)

func get_modifiers(person_id: String) -> Dictionary:
    var record := ensure_record(person_id)
    var specialization := str(record.get("specialization", "balanced"))
    var modifiers: Dictionary = SPECIALIZATIONS.get(specialization, SPECIALIZATIONS["balanced"]).duplicate(true)
    var level_bonus := 1.0 + float(int(record.get("level", 1)) - 1) * 0.025
    modifiers["attack"] = float(modifiers.get("attack", 1.0)) * level_bonus
    modifiers["defense"] = float(modifiers.get("defense", 1.0)) * level_bonus
    modifiers["health"] = float(modifiers.get("health", 1.0)) * level_bonus
    modifiers["energy"] = float(modifiers.get("energy", 1.0)) * level_bonus
    if str(record.get("career_state", "activo")) == "declive":
        modifiers["attack"] *= 0.94
        modifiers["energy"] *= 0.90
    return modifiers

func get_market_value(person_id: String) -> int:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return 0
    var record := ensure_record(person_id)
    var base := (person.strength + person.agility + person.endurance + person.intelligence) * 12
    base += int(record.get("level", 1)) * 45
    base += int(record.get("fame", 0)) * 4
    base += int(record.get("wins", 0)) * 18
    if person.injury_days > 0:
        base = int(base * 0.75)
    return maxi(50, base)

func get_specialization_name(specialization: String) -> String:
    return str(SPECIALIZATIONS.get(specialization, {}).get("name", specialization.capitalize()))

func get_specialization_ids() -> Array[String]:
    var ids: Array[String] = []
    for specialization in SPECIALIZATIONS.keys():
        ids.append(str(specialization))
    return ids

func export_state() -> Dictionary:
    return {"records":records.duplicate(true)}

func import_state(data: Dictionary) -> void:
    records = data.get("records", {}).duplicate(true)
    progression_changed.emit()

func _resolve_level_ups(person_id: String, record: Dictionary) -> void:
    var leveled := false
    while int(record.get("experience", 0)) >= _experience_required(int(record.get("level", 1))):
        record["experience"] = int(record.get("experience", 0)) - _experience_required(int(record.get("level", 1)))
        record["level"] = int(record.get("level", 1)) + 1
        record["technique_points"] = int(record.get("technique_points", 0)) + 1
        leveled = true
        gladiator_leveled.emit(person_id, int(record.get("level", 1)))
    if leveled:
        var person = RosterManager.get_person(person_id)
        if person != null:
            person.morale = mini(100, person.morale + 4)

func _experience_required(level: int) -> int:
    return 80 + level * 35
