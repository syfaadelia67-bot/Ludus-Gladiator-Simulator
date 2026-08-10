extends Node

signal roster_changed
signal monthly_results(results: Dictionary)
# Save-v14 / legacy observer alias. It mirrors the same monthly result.
signal daily_results(results: Dictionary)

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")
const MONTHLY_ROSTER_WORK_POLICY = preload(
	"res://scripts/systems/monthly_roster_work_policy.gd"
)
const JOBS := {
	"idle": "Descanso — asignación mensual",
	"mining": "Minería — asignación mensual",
	"security": "Seguridad — asignación mensual",
	"espionage": "Espionaje — asignación mensual",
	"training": "Entrenamiento — asignación mensual"
}
const JOB_DESCRIPTIONS := {
	"idle": "La asignación queda registrada. La recuperación mensual está pendiente de balance canónico.",
	"mining": "La asignación queda registrada. La producción mensual de mineral está pendiente de balance canónico.",
	"security": "La asignación queda registrada. El aporte mensual de seguridad está pendiente de balance canónico.",
	"espionage": "La asignación queda registrada. La generación mensual de información está pendiente de balance canónico.",
	"training": "La asignación queda registrada. La progresión mensual y la promoción están pendientes de balance canónico."
}

var people: Array = []
var security_score: int = 0
var intelligence_points: int = 0
var capacity: int = 8
var last_processed_month: int = 0
var last_monthly_result: Dictionary = {}


func _ready() -> void:
	if people.is_empty():
		_seed_initial_roster()


func _seed_initial_roster() -> void:
	people.clear()
	var starters := [
		{
			"id": "darian",
			"name": "Darian",
			"origin": "Tracia",
			"role": "slave",
			"strength": 8,
			"agility": 5,
			"endurance": 7,
			"resistance": 5,
			"intelligence": 3,
			"technique": 4,
			"health": 52,
			"loyalty": 48,
			"morale": 58,
			"traits": ["freedom_seeker", "vengeful"]
		},
		{
			"id": "cassia",
			"name": "Cassia",
			"origin": "Numidia",
			"role": "slave",
			"strength": 4,
			"agility": 8,
			"endurance": 5,
			"resistance": 5,
			"intelligence": 8,
			"technique": 6,
			"health": 46,
			"loyalty": 61,
			"morale": 64,
			"traits": ["superstitious", "mentor"]
		},
		{
			"id": "brenna",
			"name": "Brenna",
			"origin": "Britania",
			"role": "slave",
			"strength": 6,
			"agility": 6,
			"endurance": 8,
			"resistance": 5,
			"intelligence": 4,
			"technique": 5,
			"health": 55,
			"loyalty": 55,
			"morale": 62,
			"traits": ["protector", "beast_hunter"]
		}
	]
	for data in starters:
		people.append(PERSON_SCRIPT.new(data))
	people[0].assign_job("mining")
	people[1].assign_job("espionage")
	people[2].assign_job("training")
	roster_changed.emit()


func add_person(person) -> bool:
	if not has_capacity() or person == null:
		return false
	people.append(person)
	roster_changed.emit()
	return true


func has_capacity() -> bool:
	return people.size() < capacity


func has_gladiator() -> bool:
	for person in people:
		if person.role == "gladiator":
			return true
	return false


func get_gladiators() -> Array:
	var result: Array = []
	for person in people:
		if person.role == "gladiator":
			result.append(person)
	return result


func get_capacity_summary() -> String:
	return "%d/%d" % [people.size(), capacity]


func assign_job(person_id: String, job_id: String) -> bool:
	if not JOBS.has(job_id):
		return false
	var person = get_person(person_id)
	if person == null:
		return false
	var previous_job := str(person.job)
	person.assign_job(job_id)
	if str(person.job) != job_id:
		return false
	if previous_job != str(person.job):
		roster_changed.emit()
	return true


func get_person(person_id: String):
	for person in people:
		if person.id == person_id:
			return person
	return null


func get_people() -> Array:
	return people


func get_job_ids() -> Array[String]:
	var ids: Array[String] = []
	for job_id in JOBS.keys():
		ids.append(str(job_id))
	return ids


func get_job_name(job_id: String) -> String:
	return str(JOBS.get(job_id, job_id))


func get_job_description(job_id: String) -> String:
	return str(JOB_DESCRIPTIONS.get(job_id, "Sin descripción."))


func get_monthly_work_policy() -> Dictionary:
	return MONTHLY_ROSTER_WORK_POLICY.get_contract()


func process_month() -> Dictionary:
	var month := GameState.get_month()
	if last_processed_month == month and not last_monthly_result.is_empty():
		var cached := last_monthly_result.duplicate(true)
		cached["duplicate_call_ignored"] = true
		return cached

	var policy := get_monthly_work_policy()
	var totals := {
		"period": "month",
		"month": month,
		"ore": 0,
		"food": 0,
		"security": 0,
		"intel": 0,
		"training": 0,
		"promotions": [],
		"relationship_events": [],
		"policy_status": str(policy.get("status", "")),
		"work_balance_applied": false,
		"training_balance_applied": false,
		"fatigue_balance_applied": false,
		"injury_recovery_balance_applied": false,
		"duplicate_call_ignored": false,
	}
	for person in people:
		var result: Dictionary = person.process_month()
		totals.ore += int(result.ore)
		totals.security += int(result.security)
		totals.intel += int(result.intel)
		totals.training += int(result.training)

	totals.relationship_events = RelationshipManager.process_month(totals)
	totals.security += EstateManager.get_security_bonus()
	security_score = totals.security
	intelligence_points += totals.intel
	last_processed_month = month
	last_monthly_result = totals.duplicate(true)
	monthly_results.emit(totals.duplicate(true))
	# Legacy signal mirrors the monthly result. It is not a second tick.
	daily_results.emit(totals.duplicate(true))
	roster_changed.emit()
	return totals


func process_day() -> Dictionary:
	# Save-v14 / legacy caller adapter only.
	return process_month()


func reset_monthly_runtime_state() -> void:
	last_processed_month = 0
	last_monthly_result.clear()


func get_roster_summary() -> String:
	var lines: Array[String] = []
	for person in people:
		lines.append(person.summary())
	return "\n".join(lines)
