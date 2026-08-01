extends Node

signal career_state_changed(person_id: String, state: String)
signal gladiator_joined_staff(person_id: String, staff_role: String)

const ACTIVE := "activo"
const VETERAN := "veterano"
const DECLINE := "declive"
const RETIRED := "retirado"
const STAFF_ROLES := ["trainer", "mentor"]

func _ready() -> void:
    GameState.week_advanced.connect(func(_week: int): recalculate_all())
    CombatManager.combat_finished.connect(func(result: Dictionary):
        var person_id := str(result.get("fighter_id", ""))
        if not person_id.is_empty():
            recalculate(person_id)
    )
    SaveManager.load_completed.connect(func(_path: String): recalculate_all())
    RosterManager.roster_changed.connect(recalculate_all)
    call_deferred("recalculate_all")

func recalculate_all() -> void:
    for person in RosterManager.get_people():
        if person.role == "gladiator":
            recalculate(person.id)

func recalculate(person_id: String) -> String:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return ACTIVE
    var record := GladiatorProgressionManager.ensure_record(person_id)
    if person.role == "retired":
        record["career_state"] = RETIRED
        return RETIRED
    if person.role != "gladiator":
        return str(record.get("career_state", ACTIVE))
    var previous := str(record.get("career_state", ACTIVE))
    var resolved := _resolve_state(person_id, record)
    record["career_state"] = resolved
    record["career_weeks"] = maxi(0, int(record.get("career_weeks", 0)))
    if resolved != previous:
        GladiatorCareerJournalController.add_event(person_id, "career_state", "Nueva etapa de carrera", "%s entra en la etapa %s." % [person.display_name, get_state_name(resolved)], {"state": resolved})
        career_state_changed.emit(person_id, resolved)
        GladiatorProgressionManager.progression_changed.emit()
    return resolved

func process_week(person_id: String) -> void:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        return
    var record := GladiatorProgressionManager.ensure_record(person_id)
    record["career_weeks"] = int(record.get("career_weeks", 0)) + 1
    recalculate(person_id)

func get_state(person_id: String) -> String:
    var person = RosterManager.get_person(person_id)
    if person != null and person.role == "retired":
        return RETIRED
    return recalculate(person_id)

func get_state_name(state: String) -> String:
    match state:
        VETERAN: return "Veterano"
        DECLINE: return "Declive"
        RETIRED: return "Retirado"
        _: return "Activo"

func get_state_description(person_id: String) -> String:
    match get_state(person_id):
        VETERAN:
            return "La experiencia le concede +2 ataque, +3 precisión y +5 energía en combate."
        DECLINE:
            return "La experiencia permanece, pero el desgaste reduce ataque y energía. Puede retirarse del combate activo."
        RETIRED:
            var record := GladiatorProgressionManager.ensure_record(person_id)
            return "Sirve al ludus como %s." % get_staff_role_name(str(record.get("staff_role", "mentor")))
        _:
            return "Se encuentra en crecimiento y todavía no recibe modificadores de carrera."

func get_combat_modifiers(person_id: String) -> Dictionary:
    match get_state(person_id):
        VETERAN:
            return {"attack_bonus": 2, "accuracy_bonus": 3, "energy_bonus": 5}
        DECLINE:
            return {"attack_multiplier": 0.94, "energy_multiplier": 0.90}
        _:
            return {}

func can_retire(person_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator" or person.injury_days > 0:
        return false
    return get_state(person_id) in [VETERAN, DECLINE]

func retire_to_staff(person_id: String, staff_role: String) -> bool:
    if staff_role not in STAFF_ROLES or not can_retire(person_id):
        return false
    var person = RosterManager.get_person(person_id)
    var record := GladiatorProgressionManager.ensure_record(person_id)
    var summary := record.duplicate(true)
    summary["id"] = person_id
    summary["name"] = person.display_name
    summary["retired_week"] = GameState.get_week()
    summary["staff_role"] = staff_role
    summary["career_state"] = RETIRED
    GladiatorProgressionManager.retired_gladiators.push_front(summary)
    record["career_state"] = RETIRED
    record["retired_week"] = GameState.get_week()
    record["staff_role"] = staff_role
    person.role = "retired"
    person.job = staff_role
    GladiatorCareerJournalController.add_event(person_id, "retirement", "Retiro de la arena", "%s deja el combate activo y permanece en el ludus como %s." % [person.display_name, get_staff_role_name(staff_role)], {"staff_role": staff_role})
    GladiatorProgressionManager.gladiator_retired.emit(person_id, summary)
    gladiator_joined_staff.emit(person_id, staff_role)
    RosterManager.roster_changed.emit()
    GladiatorProgressionManager.progression_changed.emit()
    return true

func get_staff_role_name(staff_role: String) -> String:
    return "entrenador" if staff_role == "trainer" else "mentor"

func get_trainer_multiplier() -> float:
    var trainers := 0
    for person in RosterManager.get_people():
        if person.role == "retired" and person.job == "trainer":
            trainers += 1
    return 1.0 + minf(0.30, float(trainers) * 0.10)

func get_mentor_morale_bonus() -> int:
    var mentors := 0
    for person in RosterManager.get_people():
        if person.role == "retired" and person.job == "mentor":
            mentors += 1
    return mini(6, mentors * 2)

func get_retirement_preview(person_id: String) -> Dictionary:
    return {
        "eligible": can_retire(person_id),
        "state": get_state(person_id),
        "trainer_bonus": "+10% a la ganancia de entrenamiento de todo el ludus",
        "mentor_bonus": "+2 moral semanal a gladiadores que entrenan"
    }

func _resolve_state(person_id: String, record: Dictionary) -> String:
    var level := int(record.get("level", 1))
    var fights := int(record.get("wins", 0)) + int(record.get("losses", 0))
    var scars := GladiatorInjuryController.get_scars(person_id).size()
    if fights >= 14 and (scars >= 2 or level >= 9):
        return DECLINE
    if fights >= 8 or level >= 6:
        return VETERAN
    return ACTIVE
