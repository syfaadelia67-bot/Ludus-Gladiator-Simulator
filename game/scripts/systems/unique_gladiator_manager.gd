extends Node

signal unique_gladiators_changed
signal first_gladiator_acquired(gladiator_id: String)
signal unique_gladiator_unlocked(gladiator_id: String)
signal unique_gladiator_acquired(gladiator_id: String)
signal unique_gladiator_claimed_by_rival(gladiator_id: String, rival_id: String)

const INITIAL_RIVAL_IDS := ["house_varro", "house_sabina", "house_cassian"]

var states: Dictionary = {}
var first_purchase_completed: bool = false

func _ready() -> void:
    if states.is_empty(): reset_for_new_campaign()
    call_deferred("_connect_runtime_signals")

func _connect_runtime_signals() -> void:
    if not GameState.week_advanced.is_connected(_on_week_advanced): GameState.week_advanced.connect(_on_week_advanced)
    if not SaveManager.load_completed.is_connected(_on_save_loaded): SaveManager.load_completed.connect(_on_save_loaded)
    if not NewCampaignCoordinator.campaign_reset_completed.is_connected(_on_campaign_reset_completed): NewCampaignCoordinator.campaign_reset_completed.connect(_on_campaign_reset_completed)

func _on_week_advanced(week: int) -> void:
    process_market_cycle(week)

func _on_save_loaded(_path: String) -> void:
    reconcile_from_world()

func _on_campaign_reset_completed() -> void:
    reset_for_new_campaign()
    MarketManager.refresh_market(false)

func reset_for_new_campaign() -> void:
    states.clear()
    first_purchase_completed = false
    for entry in DataRepository.unique_gladiators:
        if not entry is Dictionary: continue
        var gladiator_id := str(entry.get("id", ""))
        if gladiator_id.is_empty(): continue
        states[gladiator_id] = {"status":"initial_market" if bool(entry.get("initial_candidate",false)) else "locked","rival_id":"","acquired_week":0,"available_week":1 if bool(entry.get("initial_candidate",false)) else 0,"expires_week":0}
    unique_gladiators_changed.emit()

func reconcile_from_world() -> void:
    reset_for_new_campaign()
    for person in RosterManager.get_people():
        var gladiator_id := str(person.id)
        if not states.has(gladiator_id): continue
        var state: Dictionary = states[gladiator_id]
        state["status"] = "player"
        state["acquired_week"] = GameState.get_week()
        states[gladiator_id] = state
        first_purchase_completed = true
    for rival in RivalManager.rivals:
        for raw_id in rival.get("unique_gladiators", []):
            var gladiator_id := str(raw_id)
            if not states.has(gladiator_id): continue
            var state: Dictionary = states[gladiator_id]
            state["status"] = "rival"
            state["rival_id"] = str(rival.get("id", ""))
            state["acquired_week"] = GameState.get_week()
            states[gladiator_id] = state
            first_purchase_completed = true
    for raw_offer in MarketManager.offers:
        if not raw_offer is Dictionary: continue
        var gladiator_id := str(raw_offer.get("unique_gladiator_id", ""))
        if gladiator_id.is_empty() or not states.has(gladiator_id): continue
        var entry := DataRepository.get_unique_gladiator(gladiator_id)
        if bool(entry.get("initial_candidate", false)): continue
        var state: Dictionary = states[gladiator_id]
        state["status"] = "market"
        state["available_week"] = maxi(1, int(raw_offer.get("available_week", entry.get("minimum_week", GameState.get_week()))))
        state["expires_week"] = maxi(int(state["available_week"]), int(raw_offer.get("expires_week", GameState.get_week())))
        states[gladiator_id] = state
        first_purchase_completed = true
    if first_purchase_completed:
        for gladiator_id in states.keys():
            var state: Dictionary = states[gladiator_id]
            if str(state.get("status", "")) == "initial_market":
                state["status"] = "locked"
                states[gladiator_id] = state
    process_market_cycle(GameState.get_week())
    MarketManager.sync_unique_offers()
    unique_gladiators_changed.emit()

func get_state(gladiator_id: String) -> Dictionary:
    return states.get(gladiator_id, {}).duplicate(true)

func get_initial_candidate_offers() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in DataRepository.unique_gladiators:
        if entry is Dictionary and bool(entry.get("initial_candidate", false)):
            var gladiator_id := str(entry.get("id", ""))
            if str(states.get(gladiator_id, {}).get("status", "")) == "initial_market": result.append(_to_market_offer(entry))
    return result

func get_available_market_offers() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in DataRepository.unique_gladiators:
        if not entry is Dictionary: continue
        var gladiator_id := str(entry.get("id", ""))
        var state: Dictionary = states.get(gladiator_id, {})
        if str(state.get("status", "")) != "market": continue
        var offer := _to_market_offer(entry)
        offer["available_week"] = int(state.get("available_week", 0))
        offer["expires_week"] = int(state.get("expires_week", 0))
        offer["weeks_remaining"] = maxi(0, int(state.get("expires_week", 0)) - GameState.get_week() + 1)
        result.append(offer)
    return result

func acquire_initial_gladiator(gladiator_id: String) -> bool:
    if first_purchase_completed: return false
    var state: Dictionary = states.get(gladiator_id, {})
    if str(state.get("status", "")) != "initial_market": return false
    state["status"] = "player"
    state["acquired_week"] = GameState.get_week()
    states[gladiator_id] = state
    first_purchase_completed = true
    var rival_index := 0
    for other_id in states.keys():
        if other_id == gladiator_id: continue
        if str(states[other_id].get("status", "")) != "initial_market": continue
        _move_to_rival(str(other_id), INITIAL_RIVAL_IDS[rival_index % INITIAL_RIVAL_IDS.size()], GameState.get_week())
        rival_index += 1
    first_gladiator_acquired.emit(gladiator_id)
    unique_gladiator_acquired.emit(gladiator_id)
    unique_gladiators_changed.emit()
    return true

func acquire_market_gladiator(gladiator_id: String) -> bool:
    var state: Dictionary = states.get(gladiator_id, {})
    if str(state.get("status", "")) != "market": return false
    state["status"] = "player"
    state["rival_id"] = ""
    state["acquired_week"] = GameState.get_week()
    states[gladiator_id] = state
    unique_gladiator_acquired.emit(gladiator_id)
    unique_gladiators_changed.emit()
    return true

func process_market_cycle(week: int) -> void:
    if not first_purchase_completed: return
    var changed := false
    for entry in DataRepository.unique_gladiators:
        if not entry is Dictionary or bool(entry.get("initial_candidate", false)): continue
        var gladiator_id := str(entry.get("id", ""))
        var state: Dictionary = states.get(gladiator_id, {})
        var status := str(state.get("status", "locked"))
        if status == "locked" and week >= int(entry.get("minimum_week", 99)):
            var duration := maxi(1, int(entry.get("offer_duration_weeks", 3)))
            state["status"] = "market"
            state["available_week"] = week
            state["expires_week"] = week + duration - 1
            states[gladiator_id] = state
            unique_gladiator_unlocked.emit(gladiator_id)
            changed = true
        elif status == "market" and week > int(state.get("expires_week", week)):
            _move_to_rival(gladiator_id, _select_rival_for(gladiator_id), week)
            changed = true
    if changed:
        MarketManager.sync_unique_offers()
        unique_gladiators_changed.emit()

func export_state() -> Dictionary:
    return {"states":states.duplicate(true),"first_purchase_completed":first_purchase_completed}

func import_state(data: Dictionary) -> void:
    states = data.get("states", {}).duplicate(true)
    first_purchase_completed = bool(data.get("first_purchase_completed", false))
    if states.is_empty():
        reconcile_from_world()
        return
    _sanitize_states()
    _rebuild_rival_assignments()
    process_market_cycle(GameState.get_week())
    unique_gladiators_changed.emit()

func _sanitize_states() -> void:
    var known_ids: Dictionary = {}
    for entry in DataRepository.unique_gladiators:
        if entry is Dictionary: known_ids[str(entry.get("id", ""))] = true
    for gladiator_id in states.keys():
        if not known_ids.has(str(gladiator_id)):
            states.erase(gladiator_id)
            continue
        var raw: Variant = states[gladiator_id]
        var state: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
        var status := str(state.get("status", "locked"))
        if status not in ["initial_market", "market", "player", "rival", "locked"]: status = "locked"
        states[gladiator_id] = {"status":status,"rival_id":str(state.get("rival_id","")),"acquired_week":maxi(0,int(state.get("acquired_week",0))),"available_week":maxi(0,int(state.get("available_week",0))),"expires_week":maxi(0,int(state.get("expires_week",0)))}

func _rebuild_rival_assignments() -> void:
    for rival in RivalManager.rivals: rival["unique_gladiators"] = []
    for gladiator_id in states.keys():
        var state: Dictionary = states[gladiator_id]
        if str(state.get("status", "")) == "rival": _assign_to_rival(str(state.get("rival_id", "")), str(gladiator_id))

func _select_rival_for(gladiator_id: String) -> String:
    return INITIAL_RIVAL_IDS[absi(hash("%s|%d" % [gladiator_id, GameState.get_week()])) % INITIAL_RIVAL_IDS.size()]

func _move_to_rival(gladiator_id: String, rival_id: String, week: int) -> void:
    var state: Dictionary = states.get(gladiator_id, {})
    state["status"] = "rival"
    state["rival_id"] = rival_id
    state["acquired_week"] = week
    states[gladiator_id] = state
    _assign_to_rival(rival_id, gladiator_id)
    unique_gladiator_claimed_by_rival.emit(gladiator_id, rival_id)

func _assign_to_rival(rival_id: String, gladiator_id: String) -> void:
    for rival in RivalManager.rivals:
        if str(rival.get("id", "")) != rival_id: continue
        var assigned: Array = rival.get("unique_gladiators", [])
        if not assigned.has(gladiator_id): assigned.append(gladiator_id)
        rival["unique_gladiators"] = assigned
        RivalManager.rivals_changed.emit()
        return

func _to_market_offer(entry: Dictionary) -> Dictionary:
    return {"id":"unique_%s" % str(entry.get("id","")),"unique_gladiator_id":str(entry.get("id","")),"name":str(entry.get("name","Gladiador")),"gender":str(entry.get("gender","unknown")),"origin":str(entry.get("origin","Unknown")),"role":"gladiator","strength":int(entry.get("strength",5)),"agility":int(entry.get("agility",5)),"endurance":int(entry.get("endurance",5)),"intelligence":int(entry.get("intelligence",5)),"technique":int(entry.get("technique",5)),"health":int(entry.get("health",50)),"loyalty":int(entry.get("loyalty",50)),"morale":int(entry.get("morale",50)),"traits":entry.get("traits",[]).duplicate(),"history":str(entry.get("history","")),"recommended_specializations":entry.get("recommended_specializations",[]).duplicate(),"portrait_id":str(entry.get("portrait_id","")),"sprite_id":str(entry.get("sprite_id","")),"price":int(entry.get("price",0)),"unique":true}
