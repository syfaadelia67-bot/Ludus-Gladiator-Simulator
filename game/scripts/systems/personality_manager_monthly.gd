extends "res://scripts/systems/personality_manager.gd"


func _ready() -> void:
	RosterManager.roster_changed.connect(_ensure_records)
	GameState.month_advanced.connect(_on_month_advanced)
	call_deferred("_ensure_records")


func _on_month_advanced(_month: int) -> void:
	incident_cooldown = maxi(0, incident_cooldown - 1)
	if pending_incident.is_empty() and incident_cooldown <= 0:
		_generate_internal_incident()


func process_person_month(person, result: Dictionary) -> Dictionary:
	return super.process_person_day(person, result)


func process_person_day(person, result: Dictionary) -> Dictionary:
	# Legacy caller adapter only.
	return process_person_month(person, result)
