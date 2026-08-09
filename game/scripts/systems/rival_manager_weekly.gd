extends "res://scripts/systems/rival_manager.gd"

signal monthly_rivalry_processed(month: int, events: Array)
# Compatibility signal only. It mirrors the same monthly result.
signal weekly_rivalry_processed(week: int, events: Array)


func run_operation(rival_id: String, operation_id: String, agent_id: String = "") -> Dictionary:
	var result := super.run_operation(rival_id, operation_id, agent_id)
	if result.is_empty():
		return result
	var month := GameState.get_month()
	result["month"] = month
	result["week"] = month
	result["day"] = month
	return result


func process_month() -> Array:
	# The legacy rival kernel is evaluated once per canonical month. It is not a
	# combat or standings authority and does not create extra week/day ticks.
	var events: Array = super.process_day()
	var month := GameState.get_month()
	for index in range(events.size()):
		if not events[index] is Dictionary:
			continue
		var event: Dictionary = events[index]
		event["month"] = month
		event["week"] = month
		event["day"] = month
		events[index] = event
	monthly_rivalry_processed.emit(month, events.duplicate(true))
	weekly_rivalry_processed.emit(month, events.duplicate(true))
	return events


func process_week() -> Array:
	return process_month()


func process_day() -> Array:
	return process_month()
