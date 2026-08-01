extends "res://scripts/systems/tournament_manager.gd"

signal weekly_tournaments_processed(results: Array)

const WEEK_OFFSETS := {
    "local_bout": 1,
    "forum_games": 2,
    "provincial_cup": 3,
    "imperial_trial": 4
}
const CALENDAR_BLOCK_WEEKS := 4

func generate_calendar() -> void:
    available_events.clear()
    var current_week := GameState.get_week()
    for event_id in EVENT_TYPES.keys():
        serial += 1
        var template: Dictionary = EVENT_TYPES[event_id]
        var scheduled_week := current_week + int(WEEK_OFFSETS.get(event_id, 1))
        available_events.append({
            "id":"event_%d" % serial,
            "event_type":event_id,
            "name":template.get("name", event_id),
            "scheduled_week":scheduled_week,
            "scheduled_day":scheduled_week,
            "min_reputation":int(template.get("min_reputation", 0)),
            "entry_fee":int(template.get("entry_fee", 0)),
            "base_reward":int(template.get("base_reward", 0)),
            "difficulty":int(template.get("difficulty", 1)),
            "accepted":false
        })
    calendar_changed.emit()

func accept_event(event_id: String, fighter_id: String) -> bool:
    if not super.accept_event(event_id, fighter_id):
        return false
    var contract := _find_contract(event_id)
    if not contract.is_empty():
        var scheduled_week := int(contract.get("scheduled_week", contract.get("scheduled_day", GameState.get_week())))
        contract["scheduled_week"] = scheduled_week
        contract["scheduled_day"] = scheduled_week
        contract["accepted_week"] = GameState.get_week()
        contract["accepted_day"] = GameState.get_week()
    return true

func process_week() -> Array:
    var results: Array = []
    var current_week := GameState.get_week()
    for contract in active_contracts.duplicate():
        var scheduled_week := int(contract.get("scheduled_week", contract.get("scheduled_day", current_week)))
        if scheduled_week > current_week:
            continue
        var fighter = RosterManager.get_person(str(contract.get("fighter_id", "")))
        if fighter != null and fighter.is_available_for_combat():
            continue
        var forfeit := _resolve_forfeit(contract, fighter)
        forfeit["resolved_week"] = current_week
        forfeit["resolved_day"] = current_week
        results.append(forfeit)
        active_contracts.erase(contract)
        history.push_front(forfeit.duplicate(true))
        tournament_resolved.emit(forfeit)
    if current_week % CALENDAR_BLOCK_WEEKS == 0:
        generate_calendar()
    elif not results.is_empty():
        calendar_changed.emit()
    weekly_tournaments_processed.emit(results.duplicate(true))
    return results

func process_day() -> Array:
    return process_week()

func register_combat_result(fighter_id: String, victory: bool) -> Dictionary:
    var result := super.register_combat_result(fighter_id, victory)
    if not result.is_empty():
        result["resolved_week"] = GameState.get_week()
        result["resolved_day"] = GameState.get_week()
    return result

func import_state(data: Dictionary) -> void:
    super.import_state(data)
    _migrate_week_fields(available_events)
    _migrate_week_fields(active_contracts)
    _migrate_week_fields(history)
    calendar_changed.emit()

func _migrate_week_fields(entries: Array) -> void:
    for entry in entries:
        if not entry is Dictionary:
            continue
        var scheduled_week := maxi(1, int(entry.get("scheduled_week", entry.get("scheduled_day", GameState.get_week()))))
        entry["scheduled_week"] = scheduled_week
        entry["scheduled_day"] = scheduled_week
        if entry.has("accepted_day") or entry.has("accepted_week"):
            var accepted_week := maxi(1, int(entry.get("accepted_week", entry.get("accepted_day", GameState.get_week()))))
            entry["accepted_week"] = accepted_week
            entry["accepted_day"] = accepted_week
        if entry.has("resolved_day") or entry.has("resolved_week"):
            var resolved_week := maxi(1, int(entry.get("resolved_week", entry.get("resolved_day", GameState.get_week()))))
            entry["resolved_week"] = resolved_week
            entry["resolved_day"] = resolved_week
