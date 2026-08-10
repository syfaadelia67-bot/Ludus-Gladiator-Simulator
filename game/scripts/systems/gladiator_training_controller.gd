extends Node

signal training_focus_changed(person_id: String, focus_id: String)
signal training_completed(person_id: String, result: Dictionary)

const MONTHLY_ROSTER_WORK_POLICY = preload(
	"res://scripts/systems/monthly_roster_work_policy.gd"
)
const FOCUSES := {
	"balanced":
	{
		"name": "Formación equilibrada",
		"attribute": "",
		"description": "El foco queda registrado; su progreso mensual está pendiente de balance canónico."
	},
	"strength":
	{
		"name": "Fuerza",
		"attribute": "strength",
		"description": "El foco queda registrado; su progreso mensual está pendiente de balance canónico."
	},
	"agility":
	{
		"name": "Agilidad",
		"attribute": "agility",
		"description": "El foco queda registrado; su progreso mensual está pendiente de balance canónico."
	},
	"endurance":
	{
		"name": "Aguante",
		"attribute": "endurance",
		"description": "El foco queda registrado; su progreso mensual está pendiente de balance canónico."
	},
	"technique":
	{
		"name": "Técnica",
		"attribute": "technique",
		"description": "El foco queda registrado; su progreso mensual está pendiente de balance canónico."
	},
	"specialization":
	{
		"name": "Dominio de especialización",
		"attribute": "",
		"description": "El foco queda registrado; su progreso mensual está pendiente de mecánicas congeladas."
	}
}


func _ready() -> void:
	# No calendar signal is connected here. RosterManager owns the single monthly
	# management tick; this controller cannot schedule a second training tick.
	RosterManager.roster_changed.connect(_ensure_records)
	SaveManager.load_completed.connect(func(_path: String): _ensure_records())
	call_deferred("_ensure_records")


func get_focus_ids() -> Array[String]:
	var result: Array[String] = []
	for focus_id in FOCUSES.keys():
		result.append(str(focus_id))
	return result


func get_focus_data(focus_id: String) -> Dictionary:
	return FOCUSES.get(focus_id, FOCUSES["balanced"]).duplicate(true)


func get_focus(person_id: String) -> String:
	var record := GladiatorProgressionManager.ensure_record(person_id)
	_sanitize_record(record)
	return str(record.get("training_focus", "balanced"))


func set_focus(person_id: String, focus_id: String) -> bool:
	var person = RosterManager.get_person(person_id)
	if person == null or person.role != "gladiator" or not FOCUSES.has(focus_id):
		return false
	if (
		focus_id == "specialization"
		and not SpecializationMasteryController.has_selected_specialization(person_id)
	):
		return false
	var record := GladiatorProgressionManager.ensure_record(person_id)
	_sanitize_record(record)
	record["training_focus"] = focus_id
	training_focus_changed.emit(person_id, focus_id)
	GladiatorProgressionManager.progression_changed.emit()
	return true


func get_preview(person_id: String) -> Dictionary:
	var person = RosterManager.get_person(person_id)
	if person == null or person.role != "gladiator":
		return {}
	var focus_id := get_focus(person_id)
	var policy := MONTHLY_ROSTER_WORK_POLICY.get_contract()
	return {
		"focus_id": focus_id,
		"focus_name": get_focus_data(focus_id).get("name", focus_id),
		"monthly_gain": 0,
		# Save-v14 / legacy presentation alias only.
		"weekly_gain": 0,
		"fatigue_gain": 0,
		"injury_risk": 0,
		"assigned": person.job == "training",
		"available": person.injury_days <= 0,
		"progress": _focus_progress(GladiatorProgressionManager.ensure_record(person_id), focus_id),
		"balance_ready": false,
		"policy_status": str(policy.get("status", "")),
		"trainer_multiplier": 1.0,
		"mentor_morale_bonus": 0,
	}


func process_month(month: int) -> void:
	# Numeric progression, fatigue, mastery and training injuries remain disabled
	# until their monthly rules are explicitly frozen. The focus selection itself
	# is persistent and safe to edit while balance is pending.
	if not MONTHLY_ROSTER_WORK_POLICY.TRAINING_PROGRESS_ENABLED:
		return
	for person in RosterManager.get_people():
		if person.role != "gladiator" or person.job != "training" or person.injury_days > 0:
			continue
		var record := GladiatorProgressionManager.ensure_record(person.id)
		_sanitize_record(record)
		if int(record.get("last_individual_training_month", 0)) >= month:
			continue
		record["last_individual_training_month"] = month
		record["last_individual_training_week"] = month


func process_week(week: int) -> void:
	# Save-v14 / legacy caller adapter only. It cannot create an extra training tick.
	process_month(week)


func _focus_progress(record: Dictionary, focus_id: String) -> int:
	if focus_id == "specialization":
		return maxi(0, int(record.get("specialization_progress", 0)))
	if focus_id == "balanced":
		var values: Dictionary = record.get("balanced_training_progress", {})
		var total := 0
		for value in values.values():
			total += maxi(0, int(value))
		return total
	return maxi(0, int(record.get("%s_training_progress" % focus_id, 0)))


func _ensure_records() -> void:
	for person in RosterManager.get_people():
		if person.role == "gladiator":
			_sanitize_record(GladiatorProgressionManager.ensure_record(person.id))


func _sanitize_record(record: Dictionary) -> void:
	var focus_id := str(record.get("training_focus", "balanced"))
	if not FOCUSES.has(focus_id):
		focus_id = "balanced"
	record["training_focus"] = focus_id
	record["training_sessions"] = maxi(0, int(record.get("training_sessions", 0)))
	var last_month := maxi(
		0,
		int(
			record.get(
				"last_individual_training_month",
				record.get("last_individual_training_week", 0),
			)
		),
	)
	record["last_individual_training_month"] = last_month
	# Save-v14 compatibility alias only.
	record["last_individual_training_week"] = last_month
	for attribute in ["strength", "agility", "endurance", "technique"]:
		var key := "%s_training_progress" % attribute
		record[key] = maxi(0, int(record.get(key, 0)))
	var balanced: Dictionary = (
		record.get("balanced_training_progress", {})
		if record.get("balanced_training_progress", {}) is Dictionary
		else {}
	)
	var clean_balanced := {}
	for attribute in ["strength", "agility", "endurance", "technique"]:
		clean_balanced[attribute] = maxi(0, int(balanced.get(attribute, 0)))
	record["balanced_training_progress"] = clean_balanced
