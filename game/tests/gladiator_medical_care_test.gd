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

	var fighter: LudusPerson = (
		PERSON_SCRIPT
		. new(
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
	)
	fighter.apply_injury("Fractura de costillas", 3, 4)
	RosterManager.people.append(fighter)
	assert(GladiatorInjuryController.register_existing_injury(fighter.id, "Prueba médica"))

	var basic := GladiatorMedicalCareController.get_treatment("basic", fighter.id)
	_assert(basic.get("balance_ready") == true, "Tratamientos deben declarar balance congelado.")
	_assert(int(basic.get("cost", 0)) > 0, "El tratamiento debe exponer su costo authored.")
	_assert(
		int(basic.get("recovery_months", 0)) == 1,
		"Atención básica debe reducir un mes de recuperación.",
	)
	_assert(
		GladiatorMedicalCareController.can_purchase_treatment(fighter.id, "basic"),
		"Un gladiador lesionado con fondos e Enfermería debe poder tratarse.",
	)
	var denarii_before := GameState.denarii
	var treatment_cost := int(basic.get("cost", 0))
	_assert(
		GladiatorMedicalCareController.purchase_treatment(fighter.id, "basic"),
		"La compra mensual de tratamiento debe resolverse.",
	)
	_assert(fighter.injury_days == 3, "El tratamiento básico debe reducir un mes.")
	_assert(GameState.denarii == denarii_before - treatment_cost, "Debe cobrar el costo calculado.")
	_assert(
		not GladiatorMedicalCareController.can_purchase_treatment(fighter.id, "basic"),
		"No puede comprarse un segundo tratamiento para el mismo gladiador en el mismo mes.",
	)
	_assert(
		GladiatorMedicalCareController.get_treatment_history(fighter.id).size() == 1,
		"La compra debe persistir en el historial médico.",
	)

	_assert(
		GladiatorMedicalCareController.set_priority(fighter.id),
		"Un gladiador lesionado puede recibir prioridad médica.",
	)
	var before_priority := fighter.injury_days
	GladiatorMedicalCareController.process_month(GameState.get_month() + 1)
	_assert(
		fighter.injury_days < before_priority,
		"La prioridad de Enfermería debe aplicar su reducción authored una vez por tick invocado.",
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
		"Atención médica debe respetar la política mensual congelada.",
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
