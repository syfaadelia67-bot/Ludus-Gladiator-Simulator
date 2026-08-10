extends "res://scripts/systems/relationship_manager.gd"

const MONTHLY_ROSTER_WORK_POLICY = preload("res://scripts/systems/monthly_roster_work_policy.gd")


func _ready() -> void:
	RosterManager.roster_changed.connect(_ensure_all_pairs)
	CombatManager.combat_finished.connect(_on_combat_finished)
	GameState.month_advanced.connect(_on_month_advanced)
	call_deferred("_ensure_all_pairs")


func _on_month_advanced(month: int) -> void:
	_reset_interventions_for_week(month)
	relationships_changed.emit()


func process_month(totals: Dictionary) -> Array:
	# Social state is still evaluated by the compatibility kernel, but its
	# job-linked training bonus cannot bypass the fail-closed roster policy.
	var training_before := int(totals.get("training", 0))
	var events: Array = super.process_day(totals)
	if not MONTHLY_ROSTER_WORK_POLICY.TRAINING_PROGRESS_ENABLED:
		totals["training"] = training_before
	return events


func process_day(totals: Dictionary) -> Array:
	# Legacy caller adapter only.
	return process_month(totals)
