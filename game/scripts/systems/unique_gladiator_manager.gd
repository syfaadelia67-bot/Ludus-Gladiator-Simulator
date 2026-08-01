extends Node

signal unique_gladiators_changed
signal first_gladiator_acquired(gladiator_id: String)

const INITIAL_RIVAL_IDS := ["house_varro", "house_sabina", "house_cassian"]

var states: Dictionary = {}
var first_purchase_completed: bool = false

func _ready() -> void:
    if states.is_empty():
        reset_for_new_campaign()

func reset_for_new_campaign() -> void:
    states.clear()
    first_purchase_completed = false
    for entry in DataRepository.unique_gladiators:
        if not entry is Dictionary:
            continue
        var gladiator_id := str(entry.get("id", ""))
        if gladiator_id.is_empty():
            continue
        states[gladiator_id] = {
            "status": "initial_market" if bool(entry.get("initial_candidate", false)) else "locked",
            "rival_id": "",
            "acquired_week": 0
        }
    unique_gladiators_changed.emit()

func get_state(gladiator_id: String) -> Dictionary:
    return states.get(gladiator_id, {}).duplicate(true)

func get_initial_candidate_offers() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in DataRepository.unique_gladiators:
        if not entry is Dictionary or not bool(entry.get("initial_candidate", false)):
            continue
        var gladiator_id := str(entry.get("id", ""))
        if str(states.get(gladiator_id, {}).get("status", "")) != "initial_market":
            continue
        result.append(_to_market_offer(entry))
    return result

func acquire_initial_gladiator(gladiator_id: String) -> bool:
    if first_purchase_completed:
        return false
    var state: Dictionary = states.get(gladiator_id, {})
    if str(state.get("status", "")) != "initial_market":
        return false
    state["status"] = "player"
    state["acquired_week"] = GameState.get_week()
    states[gladiator_id] = state
    first_purchase_completed = true

    var rival_index := 0
    for other_id in states.keys():
        if other_id == gladiator_id:
            continue
        var other_state: Dictionary = states[other_id]
        if str(other_state.get("status", "")) != "initial_market":
            continue
        var rival_id := INITIAL_RIVAL_IDS[rival_index % INITIAL_RIVAL_IDS.size()]
        other_state["status"] = "rival"
        other_state["rival_id"] = rival_id
        other_state["acquired_week"] = GameState.get_week()
        states[other_id] = other_state
        RivalManager.assign_unique_gladiator(rival_id, str(other_id))
        rival_index += 1

    first_gladiator_acquired.emit(gladiator_id)
    unique_gladiators_changed.emit()
    return true

func unlock_available_gladiators(week: int) -> void:
    var changed := false
    for entry in DataRepository.unique_gladiators:
        if not entry is Dictionary or bool(entry.get("initial_candidate", false)):
            continue
        var gladiator_id := str(entry.get("id", ""))
        var state: Dictionary = states.get(gladiator_id, {})
        if str(state.get("status", "")) != "locked":
            continue
        if week >= int(entry.get("minimum_week", 99)):
            state["status"] = "market"
            states[gladiator_id] = state
            changed = true
    if changed:
        unique_gladiators_changed.emit()

func export_state() -> Dictionary:
    return {
        "states": states.duplicate(true),
        "first_purchase_completed": first_purchase_completed
    }

func import_state(data: Dictionary) -> void:
    states = data.get("states", {}).duplicate(true)
    first_purchase_completed = bool(data.get("first_purchase_completed", false))
    if states.is_empty():
        reset_for_new_campaign()
        return
    _sanitize_states()
    unique_gladiators_changed.emit()

func _sanitize_states() -> void:
    var known_ids: Dictionary = {}
    for entry in DataRepository.unique_gladiators:
        if entry is Dictionary:
            known_ids[str(entry.get("id", ""))] = true
    for gladiator_id in states.keys():
        if not known_ids.has(str(gladiator_id)):
            states.erase(gladiator_id)
            continue
        var raw: Variant = states[gladiator_id]
        var state: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
        var status := str(state.get("status", "locked"))
        if status not in ["initial_market", "market", "player", "rival", "locked"]:
            status = "locked"
        states[gladiator_id] = {
            "status": status,
            "rival_id": str(state.get("rival_id", "")),
            "acquired_week": maxi(0, int(state.get("acquired_week", 0)))
        }

func _to_market_offer(entry: Dictionary) -> Dictionary:
    return {
        "id": "unique_%s" % str(entry.get("id", "")),
        "unique_gladiator_id": str(entry.get("id", "")),
        "name": str(entry.get("name", "Gladiador")),
        "gender": str(entry.get("gender", "unknown")),
        "origin": str(entry.get("origin", "Unknown")),
        "role": "gladiator",
        "strength": int(entry.get("strength", 5)),
        "agility": int(entry.get("agility", 5)),
        "endurance": int(entry.get("endurance", 5)),
        "intelligence": int(entry.get("intelligence", 5)),
        "technique": int(entry.get("technique", 5)),
        "health": int(entry.get("health", 50)),
        "loyalty": int(entry.get("loyalty", 50)),
        "morale": int(entry.get("morale", 50)),
        "traits": entry.get("traits", []).duplicate(),
        "history": str(entry.get("history", "")),
        "recommended_specializations": entry.get("recommended_specializations", []).duplicate(),
        "portrait_id": str(entry.get("portrait_id", "")),
        "sprite_id": str(entry.get("sprite_id", "")),
        "price": int(entry.get("price", 0)),
        "unique": true
    }
