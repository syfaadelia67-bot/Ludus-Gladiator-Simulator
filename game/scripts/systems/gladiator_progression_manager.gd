extends Node

signal progression_changed
signal gladiator_leveled(person_id: String, new_level: int)
signal specialization_changed(person_id: String, specialization: String)
signal ability_upgraded(person_id: String, ability_id: String, new_level: int)
signal technique_unlocked(person_id: String, technique_id: String)
signal gladiator_retired(person_id: String, summary: Dictionary)

const DEMO_MAX_LEVEL := 10
const DEFAULT_SPECIALIZATION := "gladiator"
const SPECIALIZATION_ALIASES := {"balanced":"gladiator", "thraex":"dimachaerus"}
const LEGACY_TECHNIQUE_ALIASES := {
    "precise_strike":"precise_strike",
    "iron_guard":"feint",
    "deep_reserves":"throw_sand",
    "brutal_finish":"opportunity_strike"
}

var records: Dictionary = {}
var retired_gladiators: Array[Dictionary] = []
var specializations: Dictionary = {}
var abilities: Dictionary = {}

func _ready() -> void:
    _load_catalogs()
    CombatManager.combat_finished.connect(_on_combat_finished)
    GameState.day_advanced.connect(_on_day_advanced)
    RosterManager.roster_changed.connect(_ensure_roster_records)
    call_deferred("_ensure_roster_records")

func _load_catalogs() -> void:
    specializations.clear()
    abilities.clear()
    for entry in DataRepository.specializations:
        if entry is Dictionary:
            specializations[str(entry.get("id", ""))] = entry.duplicate(true)
    for entry in DataRepository.abilities:
        if entry is Dictionary:
            abilities[str(entry.get("id", ""))] = entry.duplicate(true)

func _on_combat_finished(result: Dictionary) -> void:
    var person_id := str(result.get("fighter_id", ""))
    if person_id.is_empty():
        return
    var difficulty := 1
    var tournament: Dictionary = result.get("tournament", {})
    if not tournament.is_empty():
        difficulty = maxi(1, int(tournament.get("difficulty", 1)))
    result["progression"] = register_combat_result(person_id, bool(result.get("victory", false)), int(result.get("rounds", 1)), difficulty)

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
    return {"experience":experience_gain, "fame":fame_gain, "level":record.get("level", 1), "levels_gained":int(record.get("level", 1)) - previous_level}

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

func canonical_specialization_id(value: String) -> String:
    var canonical := str(SPECIALIZATION_ALIASES.get(value, value))
    return canonical if specializations.has(canonical) else DEFAULT_SPECIALIZATION

func set_specialization(person_id: String, specialization: String) -> bool:
    var canonical := canonical_specialization_id(specialization)
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        return false
    var record := ensure_record(person_id)
    if int(record.get("level", 1)) < 3 and canonical != DEFAULT_SPECIALIZATION:
        return false
    if str(record.get("specialization", DEFAULT_SPECIALIZATION)) != DEFAULT_SPECIALIZATION and canonical != str(record.get("specialization")):
        return false
    record["specialization"] = canonical
    specialization_changed.emit(person_id, canonical)
    progression_changed.emit()
    return true

func upgrade_ability(person_id: String, ability_id: String) -> bool:
    if not abilities.has(ability_id):
        return false
    var record := ensure_record(person_id)
    if int(record.get("skill_points", 0)) < 1:
        return false
    var ability: Dictionary = abilities[ability_id]
    if str(ability.get("category", "basic")) == "class":
        if str(ability.get("specialization", "")) != str(record.get("specialization", DEFAULT_SPECIALIZATION)):
            return false
    var learned: Dictionary = record.get("abilities", {})
    var current_level := int(learned.get(ability_id, 0))
    var max_level := int(ability.get("max_level", 2))
    if current_level >= max_level:
        return false
    learned[ability_id] = current_level + 1
    record["abilities"] = learned
    record["skill_points"] = int(record.get("skill_points", 0)) - 1
    ability_upgraded.emit(person_id, ability_id, current_level + 1)
    technique_unlocked.emit(person_id, ability_id)
    progression_changed.emit()
    return true

func unlock_technique(person_id: String, technique_id: String) -> bool:
    return upgrade_ability(person_id, str(LEGACY_TECHNIQUE_ALIASES.get(technique_id, technique_id)))

func get_ability_level(person_id: String, ability_id: String) -> int:
    return int(ensure_record(person_id).get("abilities", {}).get(ability_id, 0))

func get_available_ability_ids(person_id: String) -> Array[String]:
    var result: Array[String] = []
    var specialization := str(ensure_record(person_id).get("specialization", DEFAULT_SPECIALIZATION))
    for ability_id in abilities.keys():
        var ability: Dictionary = abilities[ability_id]
        if str(ability.get("category", "basic")) == "basic" or str(ability.get("specialization", "")) == specialization:
            result.append(str(ability_id))
    return result

func set_tactical_plan(person_id: String, plan: Array) -> bool:
    var record := ensure_record(person_id)
    var sanitized: Array = []
    for raw_order in plan:
        if not raw_order is Dictionary or sanitized.size() >= 4:
            continue
        var ability_id := str(raw_order.get("ability_id", ""))
        if get_ability_level(person_id, ability_id) <= 0:
            continue
        sanitized.append({"ability_id":ability_id, "condition":str(raw_order.get("condition", "always"))})
    record["tactical_plan"] = sanitized
    progression_changed.emit()
    return true

func get_tactical_plan(person_id: String) -> Array:
    return ensure_record(person_id).get("tactical_plan", []).duplicate(true)

func retire_gladiator(person_id: String) -> bool:
    if not can_retire(person_id):
        return false
    var person = RosterManager.get_person(person_id)
    var record := ensure_record(person_id)
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

func can_retire(person_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    return person != null and person.role == "gladiator" and int(ensure_record(person_id).get("age_days", 0)) >= 180

func get_retired_history() -> Array[Dictionary]:
    return retired_gladiators.duplicate(true)

func get_record(person_id: String) -> Dictionary:
    return ensure_record(person_id).duplicate(true)

func get_modifiers(person_id: String) -> Dictionary:
    var record := ensure_record(person_id)
    var specialization := canonical_specialization_id(str(record.get("specialization", DEFAULT_SPECIALIZATION)))
    var level_bonus := 1.0 + float(int(record.get("level", 1)) - 1) * 0.025
    var modifiers := {"attack":level_bonus, "defense":level_bonus, "health":1.0, "energy":1.0, "attack_bonus":0, "defense_bonus":0, "energy_bonus":0, "accuracy_bonus":0, "reward_multiplier":1.0, "specialization":specialization}
    if str(record.get("career_state", "activo")) == "declive":
        modifiers["attack"] *= 0.94
        modifiers["energy"] *= 0.90
    return modifiers

func get_market_value(person_id: String) -> int:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return 0
    var record := ensure_record(person_id)
    var base := (person.strength + person.agility + person.endurance + person.intelligence + person.technique) * 12
    base += int(record.get("level", 1)) * 45 + int(record.get("fame", 0)) * 4 + int(record.get("wins", 0)) * 18
    if person.injury_days > 0:
        base = int(base * 0.75)
    if str(record.get("career_state", "activo")) == "declive":
        base = int(base * 0.80)
    return maxi(50, base)

func get_specialization_name(specialization: String) -> String:
    var canonical := canonical_specialization_id(specialization)
    return str(specializations.get(canonical, {}).get("name", canonical.capitalize()))

func get_specialization_ids() -> Array[String]:
    var ids: Array[String] = []
    for specialization in specializations.keys():
        ids.append(str(specialization))
    return ids

func get_technique_ids() -> Array[String]:
    var ids: Array[String] = []
    for ability_id in abilities.keys():
        ids.append(str(ability_id))
    return ids

func get_technique(technique_id: String) -> Dictionary:
    return abilities.get(technique_id, {}).duplicate(true)

func get_experience_required(level: int) -> int:
    return _experience_required(level)

func export_state() -> Dictionary:
    return {"records":records.duplicate(true), "retired_gladiators":retired_gladiators.duplicate(true)}

func import_state(data: Dictionary) -> void:
    records = data.get("records", {}).duplicate(true)
    retired_gladiators.assign(data.get("retired_gladiators", []))
    for person_id in records.keys():
        records[person_id] = _migrate_record(records[person_id])
    _ensure_roster_records()
    progression_changed.emit()

func _new_record() -> Dictionary:
    return {"level":1, "experience":0, "specialization":DEFAULT_SPECIALIZATION, "fame":0, "wins":0, "losses":0, "age_days":0, "career_state":"activo", "skill_points":1, "abilities":{}, "tactical_plan":[]}

func _migrate_record(raw_record: Dictionary) -> Dictionary:
    var record := raw_record.duplicate(true)
    record["level"] = clampi(int(record.get("level", 1)), 1, DEMO_MAX_LEVEL)
    record["specialization"] = canonical_specialization_id(str(record.get("specialization", DEFAULT_SPECIALIZATION)))
    if not record.has("skill_points"):
        record["skill_points"] = maxi(0, int(record.get("technique_points", 0)))
    if not record.has("abilities"):
        var migrated: Dictionary = {}
        for legacy_id in record.get("techniques", []):
            var ability_id := str(LEGACY_TECHNIQUE_ALIASES.get(str(legacy_id), str(legacy_id)))
            if abilities.has(ability_id):
                migrated[ability_id] = 1
        record["abilities"] = migrated
    if not record.has("tactical_plan"):
        record["tactical_plan"] = []
    record.erase("technique_points")
    record.erase("techniques")
    return record

func _resolve_level_ups(person_id: String, record: Dictionary) -> void:
    var leveled := false
    while int(record.get("level", 1)) < DEMO_MAX_LEVEL and int(record.get("experience", 0)) >= _experience_required(int(record.get("level", 1))):
        var current_level := int(record.get("level", 1))
        record["experience"] = int(record.get("experience", 0)) - _experience_required(current_level)
        record["level"] = current_level + 1
        record["skill_points"] = int(record.get("skill_points", 0)) + 1
        _apply_level_growth(person_id, str(record.get("specialization", DEFAULT_SPECIALIZATION)))
        leveled = true
        gladiator_leveled.emit(person_id, int(record.get("level", 1)))
    if int(record.get("level", 1)) >= DEMO_MAX_LEVEL:
        record["experience"] = 0
    if leveled:
        var person = RosterManager.get_person(person_id)
        if person != null:
            person.morale = mini(100, person.morale + 4)

func _apply_level_growth(person_id: String, specialization: String) -> void:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return
    var canonical := canonical_specialization_id(specialization)
    var growth: Dictionary = specializations.get(canonical, specializations.get(DEFAULT_SPECIALIZATION, {})).get("growth_per_level", {})
    person.apply_growth(growth)

func _experience_required(level: int) -> int:
    return 80 + level * 35
