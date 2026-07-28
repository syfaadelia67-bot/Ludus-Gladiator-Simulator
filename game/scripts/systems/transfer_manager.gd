extends Node

signal transfers_changed
signal transfer_completed(result: Dictionary)
signal transfer_failed(reason: String)

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")
const OFFER_REFRESH_COST := 20

var rival_offers: Array[Dictionary] = []
var history: Array[Dictionary] = []
var serial: int = 0

func _ready() -> void:
    if rival_offers.is_empty():
        generate_rival_offers(false)

func generate_rival_offers(charge: bool = true) -> bool:
    if charge and not GameState.spend_denarii(OFFER_REFRESH_COST):
        _fail("No hay suficientes denarios para renovar las ofertas rivales.")
        return false
    rival_offers.clear()
    for index in range(3):
        serial += 1
        var strength := randi_range(5, 10)
        var agility := randi_range(5, 10)
        var endurance := randi_range(5, 10)
        var intelligence := randi_range(3, 8)
        var price := 260 + (strength + agility + endurance + intelligence) * 18
        rival_offers.append({
            "id":"rival_transfer_%d" % serial,
            "name":["Aulus", "Crixa", "Drusus", "Neria", "Tullia", "Vindex"][randi_range(0, 5)],
            "origin":["Galia", "Tracia", "Hispania", "Numidia", "Germania"][randi_range(0, 4)],
            "role":"gladiator",
            "strength":strength,
            "agility":agility,
            "endurance":endurance,
            "intelligence":intelligence,
            "loyalty":randi_range(35, 65),
            "traits":[["ambitious", "reckless", "stoic", "cunning", "vengeful"][randi_range(0, 4)]],
            "price":price,
            "seller":"Ludus rival"
        })
    transfers_changed.emit()
    return true

func manumit(person_id: String) -> Dictionary:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return _fail("La persona seleccionada no existe.")
    if person.role == "freed":
        return _fail("Esta persona ya fue liberada.")
    var value := get_person_value(person_id)
    _apply_departure_reactions(person_id, true)
    person.role = "freed"
    person.job = "idle"
    person.loyalty = mini(100, person.loyalty + 20)
    person.morale = mini(100, person.morale + 25)
    GameState.reputation += 4
    var record := PersonalityManager.ensure_record(person_id)
    record["freedom_desire"] = 0
    record["resentment"] = maxi(0, int(record.get("resentment", 0)) - 30)
    var result := _record("manumission", person, 0, "Se concedió la libertad a %s; valor económico renunciado: %d." % [person.display_name, value])
    RosterManager.roster_changed.emit()
    GameState.resources_changed.emit()
    return result

func sell_person(person_id: String) -> Dictionary:
    var person = RosterManager.get_person(person_id)
    var validation := _validate_sale(person)
    if not validation.is_empty():
        return _fail(validation)
    var value := int(round(get_person_value(person_id) * 0.72))
    GameState.denarii += value
    GameState.reputation = maxi(0, GameState.reputation - (2 if person.role == "gladiator" else 1))
    _apply_departure_reactions(person_id, false)
    RosterManager.people.erase(person)
    var result := _record("sale", person, value, "%s fue vendido por %d denarios." % [person.display_name, value])
    RosterManager.roster_changed.emit()
    GameState.resources_changed.emit()
    return result

func negotiate_sale(person_id: String, intelligence_cost: int = 6) -> Dictionary:
    var person = RosterManager.get_person(person_id)
    var validation := _validate_sale(person)
    if not validation.is_empty():
        return _fail(validation)
    if RosterManager.intelligence_points < intelligence_cost:
        return _fail("Faltan puntos de inteligencia para negociar.")
    RosterManager.intelligence_points -= intelligence_cost
    var base := get_person_value(person_id)
    var chance := clampi(45 + person.intelligence * 3 + GameState.reputation / 3, 25, 85)
    if randi_range(1, 100) <= chance:
        var value := int(round(base * 0.90))
        GameState.denarii += value
        GameState.reputation = maxi(0, GameState.reputation - (2 if person.role == "gladiator" else 1))
        _apply_departure_reactions(person_id, false)
        RosterManager.people.erase(person)
        var result := _record("negotiated_sale", person, value, "La negociación elevó el precio de %s a %d denarios." % [person.display_name, value])
        RosterManager.roster_changed.emit()
        GameState.resources_changed.emit()
        return result
    GameState.resources_changed.emit()
    return _fail("La negociación fracasó; el comprador retiró su oferta.")

func buy_rival_offer(offer_id: String) -> Dictionary:
    if not RosterManager.has_capacity():
        return _fail("Los barracones están completos.")
    var offer := _find_offer(offer_id)
    if offer.is_empty():
        return _fail("La oferta rival ya no está disponible.")
    var price := int(offer.get("price", 0))
    if not GameState.spend_denarii(price):
        return _fail("No hay suficientes denarios.")
    var data := offer.duplicate(true)
    data.erase("price")
    data.erase("seller")
    var person = PERSON_SCRIPT.new(data)
    RosterManager.add_person(person)
    rival_offers.erase(offer)
    var result := _record("rival_purchase", person, -price, "%s fue adquirido a un ludus rival por %d denarios." % [person.display_name, price])
    transfers_changed.emit()
    return result

func pay_ransom(person_id: String) -> Dictionary:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return _fail("La persona seleccionada no existe.")
    if person.role == "freed":
        return _fail("Una persona libre no necesita rescate.")
    var cost := maxi(80, int(round(get_person_value(person_id) * 0.35)))
    if not GameState.spend_denarii(cost):
        return _fail("No hay fondos suficientes para pagar el rescate.")
    person.loyalty = mini(100, person.loyalty + 12)
    person.morale = mini(100, person.morale + 10)
    var personality := PersonalityManager.ensure_record(person_id)
    personality["freedom_desire"] = maxi(0, int(personality.get("freedom_desire", 0)) - 15)
    personality["resentment"] = maxi(0, int(personality.get("resentment", 0)) - 10)
    var result := _record("ransom", person, -cost, "El ludus pagó %d denarios para asegurar la permanencia de %s." % [cost, person.display_name])
    RosterManager.roster_changed.emit()
    return result

func get_person_value(person_id: String) -> int:
    var person = RosterManager.get_person(person_id)
    if person == null:
        return 0
    if person.role == "gladiator":
        return GladiatorProgressionManager.get_market_value(person_id)
    return maxi(60, (person.strength + person.agility + person.endurance + person.intelligence) * 14 + person.loyalty * 2)

func get_rival_offers() -> Array:
    return rival_offers.duplicate(true)

func export_state() -> Dictionary:
    return {"rival_offers":rival_offers.duplicate(true),"history":history.duplicate(true),"serial":serial}

func import_state(data: Dictionary) -> void:
    rival_offers.assign(data.get("rival_offers", []))
    history.assign(data.get("history", []))
    serial = maxi(0, int(data.get("serial", 0)))
    if rival_offers.is_empty():
        generate_rival_offers(false)
    transfers_changed.emit()

func _validate_sale(person) -> String:
    if person == null:
        return "La persona seleccionada no existe."
    if person.role == "freed":
        return "Una persona libre no puede venderse."
    if RosterManager.people.size() <= 1:
        return "El ludus no puede quedarse sin personal."
    return ""

func _apply_departure_reactions(person_id: String, freed: bool) -> void:
    for relation in RelationshipManager.get_person_relationships(person_id):
        var other_id := str(relation.get("b_id", "")) if str(relation.get("a_id", "")) == person_id else str(relation.get("a_id", ""))
        var other = RosterManager.get_person(other_id)
        if other == null:
            continue
        if str(relation.get("state", "")) == "amistad":
            other.morale = clampi(other.morale + (4 if freed else -8), 0, 100)
        elif str(relation.get("state", "")) == "enemistad":
            other.morale = mini(100, other.morale + 3)

func _find_offer(offer_id: String) -> Dictionary:
    for offer in rival_offers:
        if str(offer.get("id", "")) == offer_id:
            return offer
    return {}

func _record(type_id: String, person, amount: int, description: String) -> Dictionary:
    var result := {"type":type_id,"person_id":person.id,"person_name":person.display_name,"amount":amount,"description":description,"day":GameState.day}
    history.push_front(result.duplicate(true))
    if history.size() > 60:
        history.resize(60)
    transfer_completed.emit(result)
    transfers_changed.emit()
    return result

func _fail(reason: String) -> Dictionary:
    transfer_failed.emit(reason)
    return {"error":reason}
