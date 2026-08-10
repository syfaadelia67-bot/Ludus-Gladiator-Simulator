extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")


func run() -> void:
	var previous_people: Array = RosterManager.people.duplicate()
	var previous_records: Dictionary = GladiatorProgressionManager.records.duplicate(true)
	var previous_levels: Dictionary = EstateManager.levels.duplicate(true)
	var previous_denarii := GameState.denarii
	var previous_month := GameState.day
	var previous_campaign_over := CampaignManager.campaign_over

	RosterManager.people.clear()
	GladiatorProgressionManager.records.clear()
	GameState.day = 5
	GameState.denarii = 500
	CampaignManager.campaign_over = false
	EstateManager.levels["infirmary"] = 1

	var fighter: LudusPerson = PERSON_SCRIPT.new(
		{
			"id": "medical_test_fighter",
			"name": "Paciente",
			"role": "gladiator",
			"origin": "Hispania",
			"strength": 6,
			"agility": 6,
			"endurance": 6,
			"intelligence": 5,
			"technique": 5,
			"health": 50,
			"traits": [],
		}
	)
	fighter.apply_injury("Fractura de costillas", 3, 4)
	RosterManager.people.append(fighter)
	var record := GladiatorProgressionManager.ensure_record(fighter.id)
	record["active_injury"] = {
		"name": fighter.injury_name,
		"severity": fighter.injury_severity,
		"started_week": GameState.get_month(),
		"recovery_weeks": fighter.injury_days,
		"event_name": "Prueba médica",
	}

	var basic := GladiatorMedicalCareController.get_treatment("basic", fighter.id)
	_assert(basic.get("balance_ready") == false, "Tratamientos deben declarar balance pendiente.")
	_assert(int(basic.get("cost", -1)) == 0, "No debe exponerse un costo mensual no congelado.")
	_assert(
		int(basic.get("recovery_months", -1)) == 0,
		"No debe exponerse reducción mensual no congelada.",
	)
	_assert(
		not GladiatorMedicalCareController.can_purchase_treatment(fighter.id, "basic"),
		"Tratamientos pagados deben quedar bloqueados hasta congelar balance mensual.",
	)
	var denarii_before := GameState.denarii
	_assert(
		not GladiatorMedicalCareController.purchase_treatment(fighter.id, "basic"),
		"La compra debe fallar cerrado mientras el balance mensual esté pendiente.",
	)
	_assert(fighter.injury_days == 4, "El tratamiento bloqueado no puede reducir recuperación.")
	_assert(GameState.denarii == denarii_before, "El tratamiento bloqueado no puede cobrar denarios.")

	_assert(
		GladiatorMedicalCareController.set_priority(fighter.id),
		"La prioridad puede registrarse como estado de planificación.",
	)
	_assert(
		GladiatorMedicalCareController.is_priority(fighter.id),
		"La prioridad registrada debe persistir sin efecto numérico.",
	)
	GladiatorMedicalCareController.process_week(GameState.get_month() + 1)
	_assert(
		fighter.injury_days == 4,
		"El adaptador semanal médico no puede crear recuperación oculta.",
	)
	_assert(
		GladiatorMedicalCareController.get_treatment_history(fighter.id).is_empty(),
		"No debe registrarse tratamiento si no hubo compra canónica.",
	)

	var source := FileAccess.get_file_as_string(
		"res://scripts/systems/gladiator_medical_care_controller.gd"
	)
	_assert(
		not source.contains("GameState.week_advanced.connect"),
		"Atención médica no puede conservar scheduler semanal.",
	)
	_assert(
		not source.contains("GameState.month_advanced.connect"),
		"Atención médica no puede crear un segundo scheduler mensual.",
	)
	_assert(
		source.contains("INJURY_TREATMENT_ENABLED"),
		"Atención médica debe respetar la política mensual fail-closed.",
	)

	RosterManager.people = previous_people
	GladiatorProgressionManager.records = previous_records
	EstateManager.levels = previous_levels
	GameState.denarii = previous_denarii
	GameState.day = previous_month
	CampaignManager.campaign_over = previous_campaign_over
	print("gladiator_medical_care_test: OK")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("gladiator_medical_care_test: %s" % message)
		assert(condition, message)
