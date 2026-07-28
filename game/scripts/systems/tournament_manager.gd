extends Node

signal calendar_changed
signal contract_accepted(contract: Dictionary)
signal contract_cancelled(contract: Dictionary)
signal contract_failed(reason: String)
signal tournament_resolved(result: Dictionary)

const EVENT_TYPES := {
    "local_bout": {"name":"Duelo local","min_reputation":0,"entry_fee":15,"base_reward":90,"difficulty":1,"days_ahead":2},
    "forum_games": {"name":"Juegos del Foro","min_reputation":8,"entry_fee":35,"base_reward":180,"difficulty":2,"days_ahead":4},
    "provincial_cup": {"name":"Copa Provincial","min_reputation":20,"entry_fee":70,"base_reward":340,"difficulty":3,"days_ahead":6},
    "imperial_trial": {"name":"Prueba Imperial","min_reputation":40,"entry_fee":140,"base_reward":700,"difficulty":5,"days_ahead":8}
}

var available_events: Array[Dictionary] = []
var active_contracts: Array[Dictionary] = []
var history: Array[Dictionary] = []
var serial: int = 0

func _ready() -> void:
    if available_events.is_empty():
        generate_calendar()

func generate_calendar() -> void:
    available_events.clear()
    for event_id in EVENT_TYPES.keys():
        serial += 1
        var template: Dictionary = EVENT_TYPES[event_id]
        available_events.append({
            "id":"event_%d" % serial,
            "event_type":event_id,
            "name":template.get("name", event_id),
            "scheduled_day":GameState.day + int(template.get("days_ahead", 2)) + randi_range(0, 2),
            "min_reputation":int(template.get("min_reputation", 0)),
            "entry_fee":int(template.get("entry_fee", 0)),
            "base_reward":int(template.get("base_reward", 0)),
            "difficulty":int(template.get("difficulty", 1)),
            "accepted":false
        })
    calendar_changed.emit()

func get_available_events() -> Array:
    return available_events.duplicate(true)

func get_active_contracts() -> Array:
    return active_contracts.duplicate(true)

func accept_event(event_id: String, fighter_id: String) -> bool:
    var event := _find_event(event_id)
    var fighter = RosterManager.get_person(fighter_id)
    if event.is_empty():
        contract_failed.emit("El evento seleccionado ya no está disponible.")
        return false
    if fighter == null or fighter.role != "gladiator":
        contract_failed.emit("Seleccioná un gladiador válido.")
        return false
    if not fighter.is_available_for_combat():
        contract_failed.emit("El gladiador no está disponible para competir.")
        return false
    if GameState.reputation < int(event.get("min_reputation", 0)):
        contract_failed.emit("La reputación del ludus es insuficiente.")
        return false
    for contract in active_contracts:
        if str(contract.get("fighter_id", "")) == fighter_id:
            contract_failed.emit("Ese gladiador ya tiene un combate programado.")
            return false
    var fee := int(event.get("entry_fee", 0))
    if not GameState.spend_denarii(fee):
        contract_failed.emit("No hay suficientes denarios para pagar la inscripción.")
        return false
    var contract := event.duplicate(true)
    contract["fighter_id"] = fighter_id
    contract["fighter_name"] = fighter.display_name
    contract["accepted_day"] = GameState.day
    contract["status"] = "programado"
    active_contracts.append(contract)
    event["accepted"] = true
    contract_accepted.emit(contract.duplicate(true))
    calendar_changed.emit()
    return true

func cancel_contract(contract_id: String) -> bool:
    var contract := _find_contract(contract_id)
    if contract.is_empty():
        contract_failed.emit("El contrato de combate no existe.")
        return false
    var days_left := int(contract.get("scheduled_day", GameState.day)) - GameState.day
    var penalty := int(contract.get("entry_fee", 0))
    if days_left <= 1:
        penalty *= 2
    GameState.denarii = maxi(0, GameState.denarii - penalty)
    GameState.reputation = maxi(0, GameState.reputation - (3 if days_left <= 1 else 1))
    contract["status"] = "cancelado"
    contract["cancel_penalty"] = penalty
    history.push_front(contract.duplicate(true))
    active_contracts.erase(contract)
    contract_cancelled.emit(contract.duplicate(true))
    GameState.resources_changed.emit()
    calendar_changed.emit()
    return true

func process_day() -> Array:
    var results: Array = []
    for contract in active_contracts.duplicate():
        if int(contract.get("scheduled_day", 0)) > GameState.day + 1:
            continue
        var fighter = RosterManager.get_person(str(contract.get("fighter_id", "")))
        if fighter == null or not fighter.is_available_for_combat():
            var forfeit := _resolve_forfeit(contract, fighter)
            results.append(forfeit)
            active_contracts.erase(contract)
            history.push_front(forfeit.duplicate(true))
            tournament_resolved.emit(forfeit)
    if GameState.day % 7 == 0:
        generate_calendar()
    if not results.is_empty():
        calendar_changed.emit()
    return results

func register_combat_result(fighter_id: String, victory: bool) -> Dictionary:
    var matching: Dictionary = {}
    for contract in active_contracts:
        if str(contract.get("fighter_id", "")) == fighter_id and int(contract.get("scheduled_day", 0)) <= GameState.day + 1:
            matching = contract
            break
    if matching.is_empty():
        return {}
    var difficulty := int(matching.get("difficulty", 1))
    var reward := int(matching.get("base_reward", 0)) if victory else 0
    var reputation_change := difficulty * 2 if victory else -difficulty
    if victory:
        GameState.denarii += reward
        GameState.reputation += reputation_change
    else:
        GameState.reputation = maxi(0, GameState.reputation + reputation_change)
    matching["status"] = "victoria" if victory else "derrota"
    matching["reward_paid"] = reward
    matching["reputation_change"] = reputation_change
    matching["resolved_day"] = GameState.day
    active_contracts.erase(matching)
    history.push_front(matching.duplicate(true))
    GameState.resources_changed.emit()
    calendar_changed.emit()
    tournament_resolved.emit(matching.duplicate(true))
    return matching

func export_state() -> Dictionary:
    return {
        "available_events":available_events.duplicate(true),
        "active_contracts":active_contracts.duplicate(true),
        "history":history.duplicate(true),
        "serial":serial
    }

func import_state(data: Dictionary) -> void:
    available_events.assign(data.get("available_events", []))
    active_contracts.assign(data.get("active_contracts", []))
    history.assign(data.get("history", []))
    serial = maxi(0, int(data.get("serial", 0)))
    if available_events.is_empty():
        generate_calendar()
    calendar_changed.emit()

func _resolve_forfeit(contract: Dictionary, fighter) -> Dictionary:
    var result := contract.duplicate(true)
    var penalty := int(contract.get("entry_fee", 0)) * 2
    GameState.denarii = maxi(0, GameState.denarii - penalty)
    GameState.reputation = maxi(0, GameState.reputation - 3)
    result["status"] = "incomparecencia"
    result["cancel_penalty"] = penalty
    result["resolved_day"] = GameState.day
    if fighter != null:
        fighter.morale = maxi(0, fighter.morale - 4)
    GameState.resources_changed.emit()
    return result

func _find_event(event_id: String) -> Dictionary:
    for event in available_events:
        if str(event.get("id", "")) == event_id:
            return event
    return {}

func _find_contract(contract_id: String) -> Dictionary:
    for contract in active_contracts:
        if str(contract.get("id", "")) == contract_id:
            return contract
    return {}
