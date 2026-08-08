extends "res://scripts/systems/campaign_manager.gd"

signal objective_failed(objective: Dictionary)

var failed_objectives: Array[String] = []


func _evaluate_objectives() -> void:
	_mark_expired_objectives()
	for objective in OBJECTIVES:
		var objective_id := str(objective.get("id", ""))
		if completed_objectives.has(objective_id) or failed_objectives.has(objective_id):
			continue
		if GameState.get_month() > _deadline_for_objective(objective):
			_fail_objective(objective)
			continue
		if _objective_progress(objective) < int(objective.get("target", 1)):
			continue
		completed_objectives.append(objective_id)
		GameState.denarii += int(objective.get("reward_denarii", 0))
		GameState.reputation += int(objective.get("reward_reputation", 0))
		objective_completed.emit(objective.duplicate(true))
		GameState.resources_changed.emit()


func get_objectives(chapter_id: String = "") -> Array:
	var result: Array = []
	for objective in OBJECTIVES:
		if not chapter_id.is_empty() and str(objective.get("chapter", "")) != chapter_id:
			continue
		var data: Dictionary = objective.duplicate(true)
		var objective_id := str(objective.get("id", ""))
		var deadline := _deadline_for_objective(objective)
		data["progress"] = _objective_progress(objective)
		data["completed"] = completed_objectives.has(objective_id)
		data["failed"] = failed_objectives.has(objective_id) or (
			GameState.get_month() > deadline and not bool(data["completed"])
		)
		data["deadline_month"] = deadline
		data["months_remaining"] = maxi(0, deadline - GameState.get_month() + 1)
		# Compatibility aliases for presenters/tests that have not migrated yet.
		data["deadline_week"] = deadline
		data["weeks_remaining"] = data["months_remaining"]
		result.append(data)
	return result


func export_state() -> Dictionary:
	var data := super.export_state()
	data["failed_objectives"] = failed_objectives.duplicate()
	return data


func import_state(data: Dictionary) -> void:
	super.import_state(data)
	failed_objectives.clear()
	for raw_id in data.get("failed_objectives", []):
		var objective_id := str(raw_id)
		if (
			_objective_exists(objective_id)
			and not completed_objectives.has(objective_id)
			and not failed_objectives.has(objective_id)
		):
			failed_objectives.append(objective_id)
	_mark_expired_objectives()
	campaign_changed.emit()


func _mark_expired_objectives() -> void:
	for objective in OBJECTIVES:
		var objective_id := str(objective.get("id", ""))
		if completed_objectives.has(objective_id) or failed_objectives.has(objective_id):
			continue
		if GameState.get_month() > _deadline_for_objective(objective):
			_fail_objective(objective)


func _fail_objective(objective: Dictionary) -> void:
	var objective_id := str(objective.get("id", ""))
	if (
		objective_id.is_empty()
		or completed_objectives.has(objective_id)
		or failed_objectives.has(objective_id)
	):
		return
	failed_objectives.append(objective_id)
	var failed := objective.duplicate(true)
	var deadline := _deadline_for_objective(objective)
	failed["deadline_month"] = deadline
	failed["deadline_week"] = deadline
	objective_failed.emit(failed)


func _deadline_for_objective(objective: Dictionary) -> int:
	var chapter_id := str(objective.get("chapter", ""))
	for chapter in CHAPTERS:
		if str(chapter.get("id", "")) == chapter_id:
			return int(chapter.get("month_end", chapter.get("week_end", DEMO_FINAL_MONTH)))
	return DEMO_FINAL_MONTH


func _objective_exists(objective_id: String) -> bool:
	for objective in OBJECTIVES:
		if str(objective.get("id", "")) == objective_id:
			return true
	return false
