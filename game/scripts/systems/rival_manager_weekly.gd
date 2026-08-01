extends "res://scripts/systems/rival_manager.gd"

signal weekly_rivalry_processed(week: int, events: Array)

func run_operation(rival_id: String, operation_id: String, agent_id: String = "") -> Dictionary:
    var result := super.run_operation(rival_id, operation_id, agent_id)
    if result.is_empty():
        return result
    result["week"] = GameState.get_week()
    result["day"] = GameState.get_week() # Legacy serialized alias.
    return result

func process_week() -> Array:
    var events: Array = super.process_day()
    var week := GameState.get_week()
    for index in range(events.size()):
        if not events[index] is Dictionary:
            continue
        var event: Dictionary = events[index]
        event["week"] = week
        event["day"] = week # Legacy serialized alias.
        events[index] = event
    weekly_rivalry_processed.emit(week, events.duplicate(true))
    return events

func process_day() -> Array:
    return process_week()
