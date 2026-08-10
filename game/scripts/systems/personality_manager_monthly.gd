extends "res://scripts/systems/personality_manager.gd"

const MONTHLY_ROSTER_WORK_POLICY = preload(
	"res://scripts/systems/monthly_roster_work_policy.gd"
)


func _ready() -> void:
	RosterManager.roster_changed.connect(_ensure_records)
	GameState.month_advanced.connect(_on_month_advanced)
	call_deferred("_ensure_records")


func _on_month_advanced(_month: int) -> void:
	incident_cooldown = maxi(0, incident_cooldown - 1)
	if pending_incident.is_empty() and incident_cooldown <= 0:
		_generate_internal_incident()


func process_person_month(person, result: Dictionary) -> Dictionary:
	var training_before := int(person.training)
	var result_training_before := int(result.get("training", 0))
	var result_intel_before := int(result.get("intel", 0))
	var personality_result: Dictionary = super.process_person_day(person, result)

	# Legacy trait processing contains job-linked training/intel bonuses. Those
	# bonuses cannot bypass the fail-closed monthly work policy while their balance
	# is still unfrozen. Other personality state remains owned by this subsystem.
	if not MONTHLY_ROSTER_WORK_POLICY.TRAINING_PROGRESS_ENABLED:
		person.training = training_before
		result["training"] = result_training_before
	if not MONTHLY_ROSTER_WORK_POLICY.WORK_OUTPUTS_ENABLED:
		result["intel"] = result_intel_before
	return personality_result


func process_person_day(person, result: Dictionary) -> Dictionary:
	# Legacy caller adapter only.
	return process_person_month(person, result)
