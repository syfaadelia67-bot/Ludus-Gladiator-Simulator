extends Node

signal treatment_purchased(person_id: String, treatment_id: String, months_reduced: int, cost: int)
signal treatment_failed(reason: String)
signal priority_changed(person_id: String)

const MONTHLY_ROSTER_WORK_POLICY = preload("res://scripts/systems/monthly_roster_work_policy.gd")
const TREATMENTS := {
	"basic":
	{
		"name": "Atención básica",
		"description": "Limpieza, vendaje y reposo supervisado.",
		"legacy_base_cost": 45,
		"legacy_recovery_units": 1,
		"required_infirmary_level": 1,
	},
	"intensive":
	{
		"name": "Tratamiento intensivo",
		"description": "Atención dedicada para una recuperación prolongada.",
		"legacy_base_cost": 95,
		"legacy_recovery_units": 2,
		"required_infirmary_level": 1,
	},
	"specialist":
	{
		"name": "Especialista externo",
		"description": "Intervención para lesiones graves y complejas.",
		"legacy_base_cost": 180,
		"legacy_recovery_units": 3,
		"required_infirmary_level": 2,
	},
}


func _ready() -> void:
	# No calendar signal is connected here. RosterManager owns the management tick,
	# and medical recovery cannot create a hidden second monthly simulation step.
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
	treatment["cost"] = 0
	treatment["recovery_months"] = 0
	treatment["balance_ready"] = MONTHLY_ROSTER_WORK_POLICY.INJURY_TREATMENT_ENABLED
	treatment["policy_status"] = str(MONTHLY_ROSTER_WORK_POLICY.get_contract().get("status", ""))
	treatment["available"] = can_purchase_treatment(person_id, treatment_id)
	return treatment


func get_treatment_cost(treatment_id: String) -> int:
	# Legacy prices cannot become canonical monthly prices by conversion.
	if not TREATMENTS.has(treatment_id) or not MONTHLY_ROSTER_WORK_POLICY.INJURY_TREATMENT_ENABLED:
		return 0
	return 0


func can_purchase_treatment(person_id: String, treatment_id: String) -> bool:
	if not MONTHLY_ROSTER_WORK_POLICY.INJURY_TREATMENT_ENABLED:
		return false
	if CampaignManager.campaign_over or not TREATMENTS.has(treatment_id):
		return false
	var person = RosterManager.get_person(person_id)
	if person == null or person.role != "gladiator" or person.injury_days <= 0:
		return false
	return false


func purchase_treatment(_person_id: String, treatment_id: String) -> bool:
	if not MONTHLY_ROSTER_WORK_POLICY.INJURY_TREATMENT_ENABLED:
		treatment_failed.emit("Tratamientos pendientes de balance mensual canónico.")
		return false
	if CampaignManager.campaign_over:
		treatment_failed.emit(
			"La campaña terminó. La atención médica está disponible solo para consulta."
		)
		return false
	if not TREATMENTS.has(treatment_id):
		treatment_failed.emit("Tratamiento desconocido.")
		return false
	return false


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
		if (
			person.role == "gladiator"
			and bool(
				GladiatorProgressionManager.ensure_record(person.id).get("medical_priority", false)
			)
		):
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


func process_month(_month: int) -> void:
	# Priority can be planned/persisted, but it has no recovery effect until its
	# monthly numeric rule is frozen.
	_sanitize_all()


func process_week(week: int) -> void:
	# Save-v14 / legacy caller adapter only. It cannot reduce recovery.
	process_month(week)


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
	return (
		EstateManager.get_level("infirmary")
		>= int(TREATMENTS[treatment_id].get("required_infirmary_level", 1))
	)


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
	var last_month := maxi(
		0,
		int(
			(
				record
				. get(
					"last_medical_treatment_month",
					record.get("last_medical_treatment_week", 0),
				)
			)
		),
	)
	record["last_medical_treatment_month"] = last_month
	record["last_medical_treatment_week"] = last_month
	var clean_history: Array[Dictionary] = []
	var raw_history = record.get("medical_treatments", [])
	if raw_history is Array:
		for raw in raw_history:
			if not raw is Dictionary or clean_history.size() >= 20:
				continue
			var month := maxi(1, int(raw.get("month", raw.get("week", 1))))
			var reduced := maxi(
				0,
				int(raw.get("months_reduced", raw.get("weeks_reduced", 0))),
			)
			(
				clean_history
				. append(
					{
						"month": month,
						"week": month,
						"treatment_id": str(raw.get("treatment_id", "basic")),
						"months_reduced": reduced,
						"weeks_reduced": reduced,
						"cost": maxi(0, int(raw.get("cost", 0))),
					}
				)
			)
	record["medical_treatments"] = clean_history
