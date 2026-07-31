extends Node

signal roster_changed
signal daily_results(results: Dictionary)

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")
const JOBS := {
    "idle": "Descanso — recupera fatiga y heridas",
    "mining": "Minería — produce mineral cada día",
    "security": "Seguridad — protege la finca",
    "espionage": "Espionaje — genera información",
    "training": "Entrenamiento — forma gladiadores"
}
const JOB_DESCRIPTIONS := {
    "idle": "No genera recursos. Reduce fatiga y permite recuperarse con mayor seguridad.",
    "mining": "Produce mineral al avanzar el día. La Fuerza y la Resistencia mejoran el resultado.",
    "security": "Aumenta la seguridad diaria del ludus y ayuda a bloquear sabotajes y represalias.",
    "espionage": "Genera puntos de inteligencia para operaciones contra casas rivales.",
    "training": "Aumenta el entrenamiento diario. Los esclavos llegan a 100 y se convierten en gladiadores."
}

var people: Array = []
var security_score: int = 0
var intelligence_points: int = 0
var capacity: int = 8

func _ready() -> void:
    if people.is_empty():
        _seed_initial_roster()

func _seed_initial_roster() -> void:
    var starters := [
        {"id":"darian","name":"Darian","origin":"Tracia","strength":8,"agility":5,"endurance":7,"intelligence":3,"loyalty":48,"traits":["freedom_seeker","vengeful"]},
        {"id":"cassia","name":"Cassia","origin":"Numidia","strength":4,"agility":8,"endurance":5,"intelligence":8,"loyalty":61,"traits":["superstitious","mentor"]},
        {"id":"marcus","name":"Marcus","origin":"Italia","role":"gladiator","strength":7,"agility":7,"endurance":6,"intelligence":5,"loyalty":72,"traits":["arena_lover","popular"]},
        {"id":"brenna","name":"Brenna","origin":"Britania","strength":6,"agility":6,"endurance":8,"intelligence":4,"loyalty":55,"traits":["protector","beast_hunter"]}
    ]
    for data in starters:
        people.append(PERSON_SCRIPT.new(data))
    people[0].assign_job("mining")
    people[1].assign_job("espionage")
    people[2].assign_job("idle")
    people[3].assign_job("training")
    roster_changed.emit()

func add_person(person) -> bool:
    if not has_capacity() or person == null:
        return false
    people.append(person)
    roster_changed.emit()
    return true

func has_capacity() -> bool:
    return people.size() < capacity

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

func process_day() -> Dictionary:
    var totals := {"ore":0,"food":0,"security":0,"intel":0,"training":0,"promotions":[],"relationship_events":[]}
    for person in people:
        var previous_role: String = person.role
        var result: Dictionary = person.process_day()
        totals.ore += int(result.ore)
        totals.security += int(result.security)
        totals.intel += int(result.intel)
        totals.training += int(result.training)
        if previous_role == "slave" and person.role == "gladiator":
            totals.promotions.append(person.display_name)
    totals.relationship_events = RelationshipManager.process_day(totals)
    totals.security += EstateManager.get_security_bonus()
    security_score = totals.security
    intelligence_points += totals.intel
    daily_results.emit(totals)
    roster_changed.emit()
    return totals

func get_roster_summary() -> String:
    var lines: Array[String] = []
    for person in people:
        lines.append(person.summary())
    return "\n".join(lines)
