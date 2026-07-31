extends Node

signal market_changed
signal purchase_completed(person_name: String, price: int)
signal purchase_failed(reason: String)

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

var offers: Array = []
var refresh_cost: int = 25
var offer_count: int = 4
var _serial: int = 0

var names := ["Aelia", "Brutus", "Caio", "Drusa", "Eira", "Felix", "Galla", "Hanno", "Iunia", "Kaeso", "Livia", "Nero"]
var origins := ["Tracia", "Numidia", "Galia", "Hispania", "Britania", "Germania", "Siria", "Grecia", "Italia"]
var trait_pool := ["beast_hunter", "arena_lover", "freedom_seeker", "protector", "vengeful", "popular", "superstitious", "mentor"]

func _ready() -> void:
    if offers.is_empty():
        refresh_market(false)

func refresh_market(charge: bool = true) -> bool:
    if charge and not GameState.spend_denarii(refresh_cost):
        purchase_failed.emit("No hay suficientes denarios para renovar el mercado.")
        return false
    offers.clear()
    for index in range(offer_count):
        offers.append(_generate_offer(index))
    market_changed.emit()
    return true

func _generate_offer(index: int) -> Dictionary:
    _serial += 1
    var rng := RandomNumberGenerator.new()
    rng.seed = int(Time.get_unix_time_from_system()) + _serial * 7919 + index * 131
    var role := "gladiator" if rng.randf() < 0.28 else "slave"
    var first_trait: String = trait_pool[rng.randi_range(0, trait_pool.size() - 1)]
    var second_trait := first_trait
    while second_trait == first_trait:
        second_trait = trait_pool[rng.randi_range(0, trait_pool.size() - 1)]
    var offer := {
        "id": "offer_%d" % _serial,
        "name": names[rng.randi_range(0, names.size() - 1)],
        "origin": origins[rng.randi_range(0, origins.size() - 1)],
        "role": role,
        "strength": rng.randi_range(3, 9),
        "agility": rng.randi_range(3, 9),
        "endurance": rng.randi_range(3, 9),
        "intelligence": rng.randi_range(3, 9),
        "technique": rng.randi_range(3, 9),
        "health": rng.randi_range(45, 65) if role == "gladiator" else rng.randi_range(40, 58),
        "loyalty": rng.randi_range(35, 75),
        "traits": [first_trait, second_trait]
    }
    offer["price"] = MarketValuation.offer_value(offer)
    return offer

func recalculate_offer_price(offer_id: String) -> int:
    var offer := get_offer(offer_id)
    if offer.is_empty():
        return 0
    offer["price"] = MarketValuation.offer_value(offer)
    market_changed.emit()
    return int(offer["price"])

func buy_offer(offer_id: String) -> bool:
    var offer := get_offer(offer_id)
    if offer.is_empty():
        purchase_failed.emit("La oferta ya no está disponible.")
        return false
    if not RosterManager.has_capacity():
        purchase_failed.emit("Los barracones están completos.")
        return false
    var price := int(offer.get("price", MarketValuation.offer_value(offer)))
    if not GameState.spend_denarii(price):
        purchase_failed.emit("No hay suficientes denarios.")
        return false
    var person_data := offer.duplicate(true)
    person_data.erase("price")
    var person = PERSON_SCRIPT.new(person_data)
    RosterManager.add_person(person)
    offers.erase(offer)
    purchase_completed.emit(person.display_name, price)
    market_changed.emit()
    return true

func get_offer(offer_id: String) -> Dictionary:
    for offer in offers:
        if str(offer.get("id", "")) == offer_id:
            return offer
    return {}

func get_offers() -> Array:
    return offers.duplicate()
