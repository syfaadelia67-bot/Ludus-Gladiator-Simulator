extends Node

signal treatment_purchased(person_id: String, treatment_id: String, weeks_reduced: int, cost: int)
signal treatment_failed(reason: String)
signal priority_changed(person_id: String)

const TREATMENTS := {
    "basic": {
        "name": "Atención básica",
        "description": "Limpieza, vendaje y reposo supervisado.",
        "base_cost": 45,
        "weeks": 1,
        "required_infirmary_level": 1
    },
    "intensive": {
        "name": "Tratamiento intensivo",
        "description": "Atención dedicada para reducir una recuperación prolongada.",
        "base_cost": 95,
        "weeks": 2,
        "required_infirmary_level": 1
    },
    "specialist": {
        "name": "Especialista externo",
        "description": "Intervención costosa para lesiones graves y complejas.",
        "base_cost": 180,
        "weeks": 3,
        "required_infirmary_level": 2
    }
}

func _ready() -> void:
    GameState.week_advanced.connect(_on_week_advanced)
    GladiatorInjuryController.injury_state_changed.connect(_on_injury_state_changed)
    SaveManager.load_completed.connect(func(_path: String): _sanitize_all())
    RosterManager.roster_changed.connect(_sanitize_all)
    call_deferred("_sanitize_all")

func get_treatment_ids() -> Array[String]:
    var ids: Array[String] = []
    for treatment_id in TREATMENTS.keys():
        ids.append(str(treatment_id))
    ids.sort()
    return ids

func get_treatment(treatment_id: String, person_id: String = "") -> Dictionary:
    if not TREATMENTS.has(treatment_id):
        return {}
    var treatment: Dictionary = TREATMENTS[treatment_id].duplicate(true)
    treatment["id"] = treatment_id
    treatment["cost"] = get_treatment_cost(treatment_id)
    treatment["available"] = can_purchase_treatment(person_id, treatment_id) if not person_id.is_empty() else _is_treatment_unlocked(treatment_id)
    return treatment

func get_treatment_cost(treatment_id: String) -> int:
    if not TREATMENTS.has(treatment_id):
        return 0
    var base_cost := int(TREATMENTS[treatment_id].get("base_cost", 0))
    var infirmary_level := EstateManager.get_level("infirmary")
    var discount := clampf(float(infirmary_level) * 0.10, 0.0, 0.30)
    return maxi(1, int(round(float(base_cost) * (1.0 - discount))))

func can_purchase_treatment(person_id: String, treatment_id: String) -> bool:
    if CampaignManager.campaign_over or not TREATMENTS.has(treatment_id):
        return false
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator" or person.injury_days <= 0:
        return false
    if not _is_treatment_unlocked(treatment_id):
        return false
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    if int(record.get("last_medical_treatment_week", 0)) == GameState.get_week():
        return false
    return GameState.denarii >= get_treatment_cost(treatment_id)

func purchase_treatment(person_id: String, treatment_id: String) -> bool:
    if CampaignManager.campaign_over:
        treatment_failed.emit("La campaña terminó. La atención médica está disponible solo para consulta.")
        return false
    if not TREATMENTS.has(treatment_id):
        treatment_failed.emit("Tratamiento desconocido.")
        return false
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator":
        treatment_failed.emit("Seleccioná un gladiador válido.")
        return false
    if person.injury_days <= 0:
        treatment_failed.emit("El gladiador no tiene una lesión activa.")
        return false
    if not _is_treatment_unlocked(treatment_id):
        treatment_failed.emit("La Enfermería no tiene el nivel requerido para ese tratamiento.")
        return false
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    if int(record.get("last_medical_treatment_week", 0)) == GameState.get_week():
        treatment_failed.emit("Ese gladiador ya recibió un tratamiento durante esta semana.")
        return false
    var cost := get_treatment_cost(treatment_id)
    if not GameState.spend_denarii(cost):
        treatment_failed.emit("No hay suficientes denarios para pagar el tratamiento.")
        return false
    record["last_medical_treatment_week"] = GameState.get_week()
    var requested_weeks := int(TREATMENTS[treatment_id].get("weeks", 1))
    var reduced := GladiatorInjuryController.reduce_recovery(person_id, requested_weeks, str(TREATMENTS[treatment_id].get("name", treatment_id)))
    if reduced <= 0:
        GameState.denarii += cost
        GameState.resources_changed.emit()
        treatment_failed.emit("El tratamiento no pudo reducir la recuperación.")
        return false
    _append_treatment_history(record, treatment_id, reduced, cost)
    GladiatorCareerJournalController.add_event(person_id, "medical_treatment", "Tratamiento médico", "%s recibió %s. Recuperación reducida en %d semana(s)." % [
        person.display_name,
        TREATMENTS[treatment_id].get("name", treatment_id),
        reduced
    ], {"treatment_id": treatment_id, "weeks_reduced": reduced, "cost": cost})
    treatment_purchased.emit(person_id, treatment_id, reduced, cost)
    return true

func set_priority(person_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null or person.role != "gladiator" or person.injury_days <= 0:
        treatment_failed.emit("Solo un gladiador lesionado puede recibir prioridad médica.")
        return false
    for candidate in RosterManager.get_people():
        if candidate.role != "gladiator":
            continue
        var record := GladiatorProgressionManager.ensure_record(candidate.id)
        record["medical_priority"] = candidate.id == person_id
    priority_changed.emit(person_id)
    GladiatorProgressionManager.progression_changed.emit()
    return true

func clear_priority() -> void:
    var previous := get_priority_person_id()
    for candidate in RosterManager.get_people():
        if candidate.role == "gladiator":
            GladiatorProgressionManager.ensure_record(candidate.id)["medical_priority"] = false
    if not previous.is_empty():
        priority_changed.emit("")
        GladiatorProgressionManager.progression_changed.emit()

func get_priority_person_id() -> String:
    for person in RosterManager.get_people():
        if person.role == "gladiator" and bool(GladiatorProgressionManager.ensure_record(person.id).get("medical_priority", false)):
            return person.id
    return ""

func is_priority(person_id: String) -> bool:
    return get_priority_person_id() == person_id

func get_treatment_history(person_id: String) -> Array[Dictionary]:
    var record := GladiatorProgressionManager.ensure_record(person_id)
    _sanitize_record(record)
    var result: Array[Dictionary] = []
    result.assign(record.get("medical_treatments", []))
    return result.duplicate(true)

func _on_week_advanced(_week: int) -> void:
    var priority_id := get_priority_person_id()
    if priority_id.is_empty() or EstateManager.get_level("infirmary") <= 0:
        return
    var person = RosterManager.get_person(priority_id)
    if person == null or person.injury_days <= 0:
        clear_priority()
        return
    var bonus_weeks := 1 + maxi(0, EstateManager.get_level("infirmary") - 2)
    var reduced := GladiatorInjuryController.reduce_recovery(priority_id, bonus_weeks, "prioridad de Enfermería")
    if reduced > 0:
        GladiatorCareerJournalController.add_event(priority_id, "medical_priority", "Prioridad de Enfermería", "%s recibió atención prioritaria y redujo su recuperación en %d semana(s)." % [person.display_name, reduced], {"weeks_reduced": reduced})

func _on_injury_state_changed(person_id: String) -> void:
    var person = RosterManager.get_person(person_id)
    if person == null or person.injury_days <= 0:
        var record := GladiatorProgressionManager.ensure_record(person_id)
        if bool(record.get("medical_priority", false)):
            record["medical_priority"] = false
            priority_changed.emit("")

func _is_treatment_unlocked(treatment_id: String) -> bool:
    if not TREATMENTS.has(treatment_id):
        return false
    return EstateManager.get_level("infirmary") >= int(TREATMENTS[treatment_id].get("required_infirmary_level", 1))

func _append_treatment_history(record: Dictionary, treatment_id: String, reduced: int, cost: int) -> void:
    var history: Array = record.get("medical_treatments", [])
    history.push_front({
        "week": GameState.get_week(),
        "treatment_id": treatment_id,
        "weeks_reduced": reduced,
        "cost": cost
    })
    if history.size() > 20:
        history.resize(20)
    record["medical_treatments"] = history
    GladiatorProgressionManager.progression_changed.emit()

func _sanitize_all() -> void:
    var priority_found := false
    for person in RosterManager.get_people():
        if person.role != "gladiator":
            continue
        var record := GladiatorProgressionManager.ensure_record(person.id)
        _sanitize_record(record)
        if bool(record.get("medical_priority", false)):
            if priority_found or person.injury_days <= 0:
                record["medical_priority"] = false
            else:
                priority_found = true

func _sanitize_record(record: Dictionary) -> void:
    record["medical_priority"] = bool(record.get("medical_priority", false))
    record["last_medical_treatment_week"] = maxi(0, int(record.get("last_medical_treatment_week", 0)))
    var clean_history: Array[Dictionary] = []
    var raw_history = record.get("medical_treatments", [])
    if raw_history is Array:
        for raw in raw_history:
            if not raw is Dictionary or clean_history.size() >= 20:
                continue
            clean_history.append({
                "week": maxi(1, int(raw.get("week", 1))),
                "treatment_id": str(raw.get("treatment_id", "basic")),
                "weeks_reduced": maxi(0, int(raw.get("weeks_reduced", 0))),
                "cost": maxi(0, int(raw.get("cost", 0)))
            })
    record["medical_treatments"] = clean_history
