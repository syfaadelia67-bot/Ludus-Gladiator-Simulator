extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

func run() -> void:
    var previous_people: Array = RosterManager.people.duplicate()
    var previous_records: Dictionary = GladiatorProgressionManager.records.duplicate(true)
    var previous_levels: Dictionary = EstateManager.levels.duplicate(true)
    var previous_denarii := GameState.denarii
    var previous_day := GameState.day
    var previous_campaign_over := CampaignManager.campaign_over

    RosterManager.people.clear()
    GladiatorProgressionManager.records.clear()
    GameState.day = 5
    GameState.denarii = 500
    CampaignManager.campaign_over = false
    EstateManager.levels["infirmary"] = 1

    var fighter: LudusPerson = PERSON_SCRIPT.new({
        "id":"medical_test_fighter",
        "name":"Paciente",
        "role":"gladiator",
        "origin":"Hispania",
        "strength":6,
        "agility":6,
        "endurance":6,
        "intelligence":5,
        "technique":5,
        "health":50,
        "traits":[]
    })
    fighter.apply_injury("Fractura de costillas", 3, 4)
    RosterManager.people.append(fighter)
    var record := GladiatorProgressionManager.ensure_record(fighter.id)
    record["active_injury"] = {
        "name": fighter.injury_name,
        "severity": fighter.injury_severity,
        "started_week": GameState.get_week(),
        "recovery_weeks": fighter.injury_days,
        "event_name": "Prueba médica"
    }

    var basic := GladiatorMedicalCareController.get_treatment("basic", fighter.id)
    _assert(int(basic.get("cost", 0)) < 45, "La Enfermería nivel 1 debe reducir el costo base del tratamiento.")
    _assert(GladiatorMedicalCareController.can_purchase_treatment(fighter.id, "basic"), "La atención básica debe estar disponible para un lesionado.")
    var denarii_before := GameState.denarii
    _assert(GladiatorMedicalCareController.purchase_treatment(fighter.id, "basic"), "La atención básica debe poder comprarse.")
    _assert(fighter.injury_days == 3, "La atención básica debe reducir una semana.")
    _assert(GameState.denarii == denarii_before - int(basic.get("cost", 0)), "El tratamiento debe cobrar su costo calculado.")
    _assert(not GladiatorMedicalCareController.purchase_treatment(fighter.id, "intensive"), "No debe permitirse un segundo tratamiento en la misma semana.")

    record = GladiatorProgressionManager.ensure_record(fighter.id)
    record["last_medical_treatment_week"] = 0
    _assert(GladiatorMedicalCareController.purchase_treatment(fighter.id, "intensive"), "El tratamiento intensivo debe estar disponible en Enfermería nivel 1.")
    _assert(fighter.injury_days == 1, "El tratamiento intensivo debe reducir dos semanas.")
    _assert(not GladiatorMedicalCareController.can_purchase_treatment(fighter.id, "specialist"), "El especialista debe requerir Enfermería nivel 2.")

    _assert(GladiatorMedicalCareController.set_priority(fighter.id), "Un lesionado debe poder recibir prioridad médica.")
    _assert(GladiatorMedicalCareController.is_priority(fighter.id), "La prioridad debe quedar registrada.")
    GladiatorMedicalCareController._on_week_advanced(GameState.get_week() + 1)
    _assert(fighter.injury_days == 0, "La prioridad debe completar la última semana de recuperación.")
    _assert(not GladiatorMedicalCareController.is_priority(fighter.id), "La prioridad debe limpiarse al completar la recuperación.")

    var history := GladiatorMedicalCareController.get_treatment_history(fighter.id)
    _assert(history.size() == 2, "Los dos tratamientos pagados deben persistir en el historial médico.")
    var exported := GladiatorProgressionManager.export_state()
    GladiatorProgressionManager.records.clear()
    GladiatorProgressionManager.import_state(exported)
    GladiatorMedicalCareController._sanitize_all()
    _assert(GladiatorMedicalCareController.get_treatment_history(fighter.id).size() == 2, "El historial médico debe conservarse al exportar e importar.")

    RosterManager.people = previous_people
    GladiatorProgressionManager.records = previous_records
    EstateManager.levels = previous_levels
    GameState.denarii = previous_denarii
    GameState.day = previous_day
    CampaignManager.campaign_over = previous_campaign_over
    print("gladiator_medical_care_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("gladiator_medical_care_test: %s" % message)
        assert(condition, message)
