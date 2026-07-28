extends Node

signal progression_changed
signal gladiator_leveled(person_id: String, new_level: int)
signal specialization_changed(person_id: String, specialization: String)
signal technique_unlocked(person_id: String, technique_id: String)
signal gladiator_retired(person_id: String, summary: Dictionary)

const SPECIALIZATIONS := {
    "balanced": {"name":"Versátil","attack":1.0,"defense":1.0,"health":1.0,"energy":1.0,"accuracy":0},
    "murmillo": {"name":"Murmillo","attack":1.08,"defense":1.14,"health":1.10,"energy":0.94,"accuracy":-2},
    "retiarius": {"name":"Retiarius","attack":1.10,"defense":0.90,"health":0.94,"energy":1.16,"accuracy":7},
    "secutor": {"name":"Secutor","attack":1.14,"defense":1.05,"health":1.02,"energy":0.98,"accuracy":1},
    "thraex": {"name":"Thraex","attack":1.06,"defense":1.08,"health":0.98,"energy":1.08,"accuracy":4}
}

const TECHNIQUES := {
    "iron_guard": {"name":"Guardia de hierro","cost":1,"min_level":2,"defense":5},
    "precise_strike": {"name":"Golpe preciso","cost":1,"min_level":2,"accuracy":8},
    "deep_reserves": {"name":"Reservas profundas","cost":1,"min_level":3,"energy":14},
    "brutal_finish": {"name":"Final brutal","cost":2,"min_level":5,"attack":8},
    "crowd_favorite": {"name":"Favor del público","cost":2,"min_level":5,"reward_multiplier":1.15}
}

var records: Dictionary = {}
var retired_gladiators: Array[Dictionary] = []

func _ready() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    GameState.day_advanced.connect(_on_day_advanced)
    RosterManager.roster_changed.connect(_ensure_roster_records)
    call_deferred("_ensure_roster_records")

func _on_combat_finished(result: Dictionary) -> void:
    var person_id := str(result.get("fighter_id", ""))
    if person_id.is_empty():
        return
    var difficulty := 1
    var tournament: Dictionary = result.get("tournament", {})
    if not tournament.is_empty():
        difficulty = maxi(1, int(tournament.get("difficulty", 1)))
    var gains := register_combat_result(person_id, bool(result.get("victory", false)), int(result.get("rounds", 1)), difficulty)
    result["progression"] = gains

func _on_day_advanced(_day: int) -> void:
    process_day()

func _ensure_roster_records() -> void:
    var changed := false
    for person in RosterManager.get_people():
        if person.role == "gladiator" and not records.has(person.id):
            records[person.id] = _new_record()
            changed = true
    if changed:
        progression_changed.emit()

func ensure_record(person_id: String) -> Dictionary:
    if not records.has(person_id):
        records[person_id] = _new_record()
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
    var previous_level := int(record.get("level", 1))
    _resolve_level_ups(person_id, record)
    progression_changed.emit()
    return {"experience":experience_gain,"fame":fame_gain,"level":record.get("level", 1),"levels_gained":int(record.get("level",1))-previous_level}

func process_day() -> void:
    var changed := false
    for person in RosterManager.get_people():
        if person.role != "gladiator":
            continue
        var record := ensure_record(person.id)
        record["age_days"] = int(record.get("age_days", 0)) + 1
        var age_days := int(record.get("age_days", 0))
        record["career_state"] = "declive" if age_days >= 540 else ("veterano" if age_days >= 360 else "activo")
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

func unlock_technique(person_id: String, technique_id: String) -> bool:
    if not TECHNIQUES.has(technique_id):
        return false
    var record := ensure_record(person_id)
    var learned: Array = record.get("techniques", [])
    if learned.has(technique_id):
        return false
    var technique: Dictionary = TECHNIQUES[technique_id]
    var cost := int(technique.get("cost", 1))
    if int(record.get("level", 1)) < int(technique.get("min_level", 1)) or int(record.get("technique_points", 0)) < cost:
        return false
    record["technique_points"] = int(record.get("technique_points", 0)) - cost
    learned.append(technique_id)
    record["techniques"] = learned
    technique_unlocked.emit(person_id, technique_id)
    progression_changed.emit()
    return true

func retire_gladiator(person_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        return false
    var record := ensure_record(person_id)
    if int(record.get("age_days", 0)) < 180:
        return false
    var summary := record.duplicate(true)
    summary["id"] = person_id
    summary["name"] = person.display_name
    summary["retired_day"] = GameState.day
    retired_gladiators.push_front(summary)
    records.erase(person_id)
    person.role = "retired"
    person.job = "idle"
    gladiator_retired.emit(person_id, summary)
    RosterManager.roster_changed.emit()
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
    modifiers["attack_bonus"] = 0
    modifiers["defense_bonus"] = 0
    modifiers["energy_bonus"] = 0
    modifiers["accuracy_bonus"] = int(modifiers.get("accuracy", 0))
    modifiers["reward_multiplier"] = 1.0
    for technique_id in record.get("techniques", []):
        var technique: Dictionary = TECHNIQUES.get(str(technique_id), {})
        modifiers["attack_bonus"] += int(technique.get("attack", 0))
        modifiers["defense_bonus"] += int(technique.get("defense", 0))
        modifiers["energy_bonus"] += int(technique.get("energy", 0))
        modifiers["accuracy_bonus"] += int(technique.get("accuracy", 0))
        modifiers["reward_multiplier"] *= float(technique.get("reward_multiplier", 1.0))
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
    if str(record.get("career_state", "activo")) == "declive":
        base = int(base * 0.80)
    return maxi(50, base)

func get_specialization_name(specialization: String) -> String:
    return str(SPECIALIZATIONS.get(specialization, {}).get("name", specialization.capitalize()))

func get_specialization_ids() -> Array[String]:
    var ids: Array[String] = []
    for specialization in SPECIALIZATIONS.keys():
        ids.append(str(specialization))
    return ids

func get_technique_ids() -> Array[String]:
    var ids: Array[String] = []
    for technique_id in TECHNIQUES.keys():
        ids.append(str(technique_id))
    return ids

func export_state() -> Dictionary:
    return {"records":records.duplicate(true),"retired_gladiators":retired_gladiators.duplicate(true)}

func import_state(data: Dictionary) -> void:
    records = data.get("records", {}).duplicate(true)
    retired_gladiators.assign(data.get("retired_gladiators", []))
    _ensure_roster_records()
    progression_changed.emit()

func _new_record() -> Dictionary:
    return {"level":1,"experience":0,"specialization":"balanced","fame":0,"wins":0,"losses":0,"age_days":0,"career_state":"activo","technique_points":0,"techniques":[]}

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
