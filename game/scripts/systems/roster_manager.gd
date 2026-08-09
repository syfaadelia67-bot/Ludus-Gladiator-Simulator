extends Node

signal roster_changed
signal monthly_results(results: Dictionary)
# Save-v14 / legacy observer alias. It mirrors the same monthly result.
signal daily_results(results: Dictionary)

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")
const JOBS := {
	"idle": "Descanso — recupera fatiga y heridas",
	"mining": "Minería — produce mineral cada mes",
	"security": "Seguridad — protege la finca",
	"espionage": "Espionaje — genera información",
	"training": "Entrenamiento — forma gladiadores"
}
const JOB_DESCRIPTIONS := {
	"idle": "No genera recursos. Reduce fatiga y permite recuperarse con mayor seguridad.",
	"mining": "Produce mineral al cerrar el mes. La Fuerza y la Resistencia mejoran el resultado.",
	"security":
	"Aumenta la seguridad mensual del ludus y ayuda a bloquear sabotajes y represalias.",
	"espionage": "Genera puntos de inteligencia para operaciones contra casas rivales.",
	"training":
	"Aumenta el entrenamiento mensual. Los esclavos llegan a 100 y se convierten en gladiadores."
}

var people: Array = []
var security_score: int = 0
var intelligence_points: int = 0
var capacity: int = 8


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
	person.assign_job(job_id)
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


func process_month() -> Dictionary:
	var totals := {
		"period": "month",
		"month": GameState.get_month(),
		"ore": 0,
		"food": 0,
		"security": 0,
		"intel": 0,
		"training": 0,
		"promotions": [],
		"relationship_events": []
	}
	for person in people:
		var previous_role: String = person.role
		var result: Dictionary = person.process_month()
		totals.ore += int(result.ore)
		totals.security += int(result.security)
		totals.intel += int(result.intel)
		totals.training += int(result.training)
		if previous_role == "slave" and person.role == "gladiator":
			totals.promotions.append(person.display_name)
	totals.relationship_events = RelationshipManager.process_month(totals)
	totals.security += EstateManager.get_security_bonus()
	security_score = totals.security
	intelligence_points += totals.intel
	monthly_results.emit(totals.duplicate(true))
	# Legacy signal mirrors the monthly result. It is not a second tick.
	daily_results.emit(totals.duplicate(true))
	roster_changed.emit()
	return totals


func process_day() -> Dictionary:
	# Save-v14 / legacy caller adapter only.
	return process_month()


func get_roster_summary() -> String:
	var lines: Array[String] = []
	for person in people:
		lines.append(person.summary())
	return "\n".join(lines)
