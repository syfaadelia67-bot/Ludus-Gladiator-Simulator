extends Node

signal mastery_changed(person_id: String, progress: int)
signal specialization_mastered(person_id: String, specialization_id: String)

const MAX_PROGRESS := 100
const COMBAT_BASE_PROGRESS := 4
const VICTORY_BONUS := 6
const TRAINING_BASE_PROGRESS := 3
const EQUIPMENT_USE_BONUS := 1

func _ready() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    GameState.week_advanced.connect(_on_week_advanced)
    RosterManager.roster_changed.connect(_ensure_records)
    GladiatorProgressionManager.specialization_changed.connect(_on_specialization_changed)
    SaveManager.load_completed.connect(func(_path: String): _ensure_records())
    call_deferred("_ensure_records")

func select_specialization(person_id: String, specialization_id: String) -> bool:
    var canonical_id := GladiatorProgressionManager.canonical_specialization_id(specialization_id)
    if canonical_id == GladiatorProgressionManager.DEFAULT_SPECIALIZATION:
        return false
    if not GladiatorProgressionManager.set_specialization(person_id, canonical_id):
        return false
    var record := GladiatorProgressionManager.ensure_record(person_id)
    record["specialization_progress"] = 0
    record["specialization_mastered"] = false
    mastery_changed.emit(person_id, 0)
    return true

func has_selected_specialization(person_id: String) -> bool:
    var record := GladiatorProgressionManager.ensure_record(person_id)
    return str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION)) != GladiatorProgressionManager.DEFAULT_SPECIALIZATION

func get_progress(person_id: String) -> int:
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    return int(record.get("specialization_progress", 0)) if has_selected_specialization(person_id) else 0

func is_mastered(person_id: String) -> bool:
    return has_selected_specialization(person_id) and get_progress(person_id) >= MAX_PROGRESS

func register_training_use(person_id: String) -> int:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator" or not has_selected_specialization(person_id):
        return 0
    return _add_progress(person_id, TRAINING_BASE_PROGRESS + _equipped_piece_count(person))

func _on_combat_finished(result: Dictionary) -> void:
    var person_id := str(result.get("fighter_id", ""))
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator" or not has_selected_specialization(person_id):
        return
    var gain := COMBAT_BASE_PROGRESS + _equipped_piece_count(person) * EQUIPMENT_USE_BONUS
    if bool(result.get("victory", false)):
        gain += VICTORY_BONUS
    _add_progress(person_id, gain)

func _on_week_advanced(_week: int) -> void:
    for person in RosterManager.get_people():
        if person.role == "gladiator" and person.job == "training":
            register_training_use(person.id)

func _on_specialization_changed(person_id: String, specialization_id: String) -> void:
    var record := GladiatorProgressionManager.ensure_record(person_id)
    if specialization_id == GladiatorProgressionManager.DEFAULT_SPECIALIZATION:
        record["specialization_progress"] = 0
        record["specialization_mastered"] = false
    else:
        _sanitize_record(record)
    mastery_changed.emit(person_id, int(record.get("specialization_progress", 0)))

func _ensure_records() -> void:
    for person in RosterManager.get_people():
        if person.role != "gladiator":
            continue
        var record := GladiatorProgressionManager.ensure_record(person.id)
        _sanitize_record(record)

func _sanitize_record(record: Dictionary) -> void:
    var specialization_id := str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION))
    if specialization_id == GladiatorProgressionManager.DEFAULT_SPECIALIZATION:
        record["specialization_progress"] = 0
        record["specialization_mastered"] = false
        return
    record["specialization_progress"] = clampi(int(record.get("specialization_progress", 0)), 0, MAX_PROGRESS)
    record["specialization_mastered"] = int(record.get("specialization_progress", 0)) >= MAX_PROGRESS

func _add_progress(person_id: String, amount: int) -> int:
    if not has_selected_specialization(person_id):
        return 0
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    var previous := int(record.get("specialization_progress", 0))
    if previous >= MAX_PROGRESS:
        return 0
    var updated := clampi(previous + maxi(0, amount), 0, MAX_PROGRESS)
    record["specialization_progress"] = updated
    record["specialization_mastered"] = updated >= MAX_PROGRESS
    mastery_changed.emit(person_id, updated)
    GladiatorProgressionManager.progression_changed.emit()
    if previous < MAX_PROGRESS and updated >= MAX_PROGRESS:
        specialization_mastered.emit(person_id, str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION)))
    return updated - previous

func _equipped_piece_count(person) -> int:
    var loadout := EquipmentManager.get_equipped_loadout(person)
    var count := 0
    if str(loadout.get("weapon_name", "Ninguno")) != "Ninguno":
        count += 1
    if str(loadout.get("armor_name", "Ninguna")) != "Ninguna":
        count += 1
    if str(loadout.get("shield_name", "Ninguno")) != "Ninguno":
        count += 1
    return count
