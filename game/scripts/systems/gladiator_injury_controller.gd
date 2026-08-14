extends Node

signal injury_state_changed(person_id: String)
signal scar_added(person_id: String, scar: Dictionary)
signal recovery_reduced(person_id: String, months: int, source: String)

const MONTHLY_ROSTER_WORK_POLICY = preload("res://scripts/systems/monthly_roster_work_policy.gd")
const MAX_SCARS := 8


func _ready() -> void:
	# Combat V1 injury creation is not frozen yet. Do not listen to the legacy
	# CombatManager and accidentally promote its injury RNG to canonical authority.
	GameState.month_advanced.connect(_on_month_advanced)
	SaveManager.load_completed.connect(func(_path: String): _sanitize_all())
	RosterManager.roster_changed.connect(_sanitize_all)
	call_deferred("_sanitize_all")


func get_active_injury(person_id: String) -> Dictionary:
	var record := GladiatorProgressionManager.ensure_record(person_id)
	_sanitize_record(record)
	return record.get("active_injury", {}).duplicate(true)


func get_scars(person_id: String) -> Array[Dictionary]:
	var record := GladiatorProgressionManager.ensure_record(person_id)
	_sanitize_record(record)
	var result: Array[Dictionary] = []
	result.assign(record.get("scars", []))
	return result.duplicate(true)


func get_summary(person_id: String) -> Dictionary:
	var person = RosterManager.get_person(person_id)
	return {
		"active": get_active_injury(person_id),
		"scars": get_scars(person_id),
		"available_for_combat": person != null and person.is_available_for_combat(),
		"recovery_policy_status": str(MONTHLY_ROSTER_WORK_POLICY.get_contract().get("status", "")),
	}


func register_existing_injury(person_id: String, event_name: String = "Arena") -> bool:
	var person = RosterManager.get_person(person_id)
	if person == null or person.role != "gladiator" or person.injury_days <= 0:
		return false
	var record := GladiatorProgressionManager.ensure_record(person_id)
	var month := GameState.get_month()
	record["active_injury"] = {
		"name": person.injury_name,
		"severity": clampi(person.injury_severity, 1, 3),
		"started_month": month,
		"recovery_months": person.injury_days,
		# Save-v14 compatibility aliases. They mirror month semantics 1:1.
		"started_week": month,
		"recovery_weeks": person.injury_days,
		"event_name": event_name,
	}
	injury_state_changed.emit(person_id)
	GladiatorProgressionManager.progression_changed.emit()
	return true


func reduce_recovery_months(person_id: String, months: int, source: String = "tratamiento") -> int:
	if not MONTHLY_ROSTER_WORK_POLICY.INJURY_TREATMENT_ENABLED:
		return 0
	var person = RosterManager.get_person(person_id)
	if person == null or person.role != "gladiator" or person.injury_days <= 0:
		return 0
	var reduction := mini(person.injury_days, maxi(0, months))
	if reduction <= 0:
		return 0
	var record := GladiatorProgressionManager.ensure_record(person_id)
	_sanitize_record(record)
	var active: Dictionary = record.get("active_injury", {})
	if active.is_empty():
		register_existing_injury(person_id, "Tratamiento médico")
		active = record.get("active_injury", {})
	person.injury_days = maxi(0, person.injury_days - reduction)
	_set_recovery_months(active, person.injury_days)
	record["active_injury"] = active
	recovery_reduced.emit(person_id, reduction, source)
	if person.injury_days <= 0:
		person.injury_severity = 0
		person.injury_name = ""
		_complete_recovery(person, record, active)
	else:
		injury_state_changed.emit(person_id)
		GladiatorProgressionManager.progression_changed.emit()
	RosterManager.roster_changed.emit()
	return reduction


func reduce_recovery(person_id: String, weeks: int, source: String = "tratamiento") -> int:
	# Save-v14 / legacy API alias. The numeric payload is interpreted as months.
	return reduce_recovery_months(person_id, weeks, source)


func _on_month_advanced(_month: int) -> void:
	for person in RosterManager.get_people():
		if person.role != "gladiator":
			continue
		var record := GladiatorProgressionManager.ensure_record(person.id)
		_sanitize_record(record)
		var active: Dictionary = record.get("active_injury", {})
		if active.is_empty():
			continue
		if person.injury_days > 0:
			_set_recovery_months(active, person.injury_days)
			record["active_injury"] = active
			injury_state_changed.emit(person.id)
			continue
		_complete_recovery(person, record, active)


func _set_recovery_months(active: Dictionary, months: int) -> void:
	active["recovery_months"] = maxi(0, months)
	# Save-v14 compatibility alias only.
	active["recovery_weeks"] = maxi(0, months)


func _complete_recovery(person, record: Dictionary, injury: Dictionary) -> void:
	record["active_injury"] = {}
	var severity := int(injury.get("severity", 1))
	var creates_scar := severity >= 3
	if severity == 2:
		var started_month := int(injury.get("started_month", injury.get("started_week", 1)))
		var seed_text := "%s|%s|%d" % [person.id, injury.get("name", "Herida"), started_month]
		creates_scar = absi(hash(seed_text)) % 100 < 35
	if creates_scar:
		_add_scar(person, record, injury)
	(
		GladiatorCareerJournalController
		. add_event(
			person.id,
			"recovery",
			"Recuperación completada",
			(
				"%s se recuperó de %s.%s"
				% [
					person.display_name,
					injury.get("name", "una herida"),
					" La lesión dejó una secuela permanente." if creates_scar else ""
				]
			),
			{"severity": severity, "scar": creates_scar},
		)
	)
	injury_state_changed.emit(person.id)
	GladiatorProgressionManager.progression_changed.emit()


func _add_scar(person, record: Dictionary, injury: Dictionary) -> void:
	var scars: Array = record.get("scars", [])
	var penalty := _penalty_for_injury(
		str(injury.get("name", "Herida")), int(injury.get("severity", 1))
	)
	var month := GameState.get_month()
	var scar := {
		"name": _scar_name(str(injury.get("name", "Herida"))),
		"source_injury": str(injury.get("name", "Herida")),
		"month": month,
		# Save-v14 compatibility alias only.
		"week": month,
		"penalty": penalty.duplicate(true),
	}
	scars.push_front(scar)
	if scars.size() > MAX_SCARS:
		scars.resize(MAX_SCARS)
	record["scars"] = scars
	person.apply_growth(penalty)
	(
		GladiatorCareerJournalController
		. add_event(
			person.id,
			"scar",
			"Cicatriz permanente",
			"%s conserva %s como recuerdo de la arena." % [person.display_name, scar.name],
			scar,
		)
	)
	scar_added.emit(person.id, scar.duplicate(true))


func _penalty_for_injury(injury_name: String, severity: int) -> Dictionary:
	var lowered := injury_name.to_lower()
	if "fractura" in lowered or "luxación" in lowered:
		return {"agility": -1}
	if "desgarro" in lowered or "trauma" in lowered:
		return {"endurance": -1}
	if severity >= 3:
		return {"health": -5}
	return {"technique": -1}


func _scar_name(injury_name: String) -> String:
	var lowered := injury_name.to_lower()
	if "bestia" in lowered:
		return "cicatriz de garras"
	if "fractura" in lowered:
		return "secuela de fractura"
	if "trauma" in lowered:
		return "dolor persistente"
	return "cicatriz de combate"


func _sanitize_all() -> void:
	for person in RosterManager.get_people():
		if person.role == "gladiator":
			_sanitize_record(GladiatorProgressionManager.ensure_record(person.id))


func _sanitize_record(record: Dictionary) -> void:
	var active = record.get("active_injury", {})
	if active is Dictionary and not (active as Dictionary).is_empty():
		var clean_active := (active as Dictionary).duplicate(true)
		var started_month := maxi(
			1, int(clean_active.get("started_month", clean_active.get("started_week", 1)))
		)
		var recovery_months := maxi(
			0, int(clean_active.get("recovery_months", clean_active.get("recovery_weeks", 0)))
		)
		clean_active["started_month"] = started_month
		clean_active["recovery_months"] = recovery_months
		clean_active["started_week"] = started_month
		clean_active["recovery_weeks"] = recovery_months
		record["active_injury"] = clean_active
	else:
		# An empty dictionary means there is no active injury. Do not materialize
		# compatibility date fields into it, or it becomes falsely non-empty.
		record["active_injury"] = {}

	var clean_scars: Array[Dictionary] = []
	var raw_scars = record.get("scars", [])
	if raw_scars is Array:
		for raw in raw_scars:
			if not raw is Dictionary or clean_scars.size() >= MAX_SCARS:
				continue
			var scar_month := maxi(1, int(raw.get("month", raw.get("week", 1))))
			(
				clean_scars
				. append(
					{
						"name": str(raw.get("name", "cicatriz de combate")),
						"source_injury": str(raw.get("source_injury", "Herida")),
						"month": scar_month,
						"week": scar_month,
						"penalty":
						(
							raw.get("penalty", {}).duplicate(true)
							if raw.get("penalty", {}) is Dictionary
							else {}
						),
					}
				)
			)
	record["scars"] = clean_scars
