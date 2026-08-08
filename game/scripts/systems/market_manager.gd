extends Node

signal market_changed
signal purchase_completed(person_name: String, price: int)
signal purchase_failed(reason: String)
signal equipment_market_changed
signal equipment_purchase_completed(item_name: String, price: int)
signal equipment_purchase_failed(reason: String)

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")
const AUTO_REFRESH_WEEKS := 3
const EQUIPMENT_REFRESH_COST := 100
const EQUIPMENT_OFFER_COUNT := 6

var offers: Array = []
# Conservado para compatibilidad con scripts antiguos. La renovación manual de
# luchadores ya no está disponible: solo el equipamiento se renueva por 100.
var refresh_cost: int = EQUIPMENT_REFRESH_COST
var offer_count: int = 4
var equipment_offers: Array[Dictionary] = []
var last_auto_refresh_week: int = 1
var names := [
	"Aelia",
	"Brutus",
	"Caio",
	"Drusa",
	"Eira",
	"Felix",
	"Galla",
	"Hanno",
	"Iunia",
	"Kaeso",
	"Livia",
	"Nero"
]
var origins := [
	"Tracia", "Numidia", "Galia", "Hispania", "Britania", "Germania", "Siria", "Grecia", "Italia"
]
var _serial: int = 0
var _equipment_offer_serial: int = 0


func _ready() -> void:
	if not GameState.week_advanced.is_connected(_on_week_advanced):
		GameState.week_advanced.connect(_on_week_advanced)
	if offers.is_empty():
		refresh_market(false)
	if equipment_offers.is_empty():
		refresh_equipment_market(false)
	last_auto_refresh_week = maxi(1, last_auto_refresh_week)


func refresh_market(charge: bool = true) -> bool:
	if CampaignManager.campaign_over:
		purchase_failed.emit("La campaña terminó. El mercado está disponible solo para consulta.")
		return false
	if charge:
		purchase_failed.emit(
			"Las ofertas de luchadores se renuevan automáticamente cada 3 semanas."
		)
		return false
	if not UniqueGladiatorManager.first_purchase_completed:
		offers = UniqueGladiatorManager.get_initial_candidate_offers()
		market_changed.emit()
		return true
	offers.clear()
	offers.append_array(UniqueGladiatorManager.get_available_market_offers())
	for index in range(offer_count):
		offers.append(_generate_offer(index))
	market_changed.emit()
	return true


func refresh_equipment_market(charge: bool = true) -> bool:
	if CampaignManager.campaign_over:
		equipment_purchase_failed.emit(
			"La campaña terminó. El mercado está disponible solo para consulta."
		)
		return false
	if charge and not GameState.spend_denarii(EQUIPMENT_REFRESH_COST):
		equipment_purchase_failed.emit(
			"Se necesitan %d denarios para renovar el equipamiento." % EQUIPMENT_REFRESH_COST
		)
		return false
	equipment_offers.clear()
	var recipe_ids := EquipmentManager.get_recipe_ids()
	recipe_ids.shuffle()
	var count := mini(EQUIPMENT_OFFER_COUNT, recipe_ids.size())
	for index in range(count):
		equipment_offers.append(_generate_equipment_offer(recipe_ids[index], index))
	equipment_market_changed.emit()
	return true


func _on_week_advanced(week: int) -> void:
	if week < last_auto_refresh_week:
		last_auto_refresh_week = week
	if week - last_auto_refresh_week < AUTO_REFRESH_WEEKS:
		return
	last_auto_refresh_week = week
	refresh_market(false)
	refresh_equipment_market(false)


func get_next_auto_refresh_week() -> int:
	return last_auto_refresh_week + AUTO_REFRESH_WEEKS


func get_weeks_until_auto_refresh() -> int:
	return maxi(0, get_next_auto_refresh_week() - GameState.get_week())


func sync_unique_offers() -> void:
	if not UniqueGladiatorManager.first_purchase_completed:
		offers = UniqueGladiatorManager.get_initial_candidate_offers()
		market_changed.emit()
		return
	var random_offers: Array = []
	for offer in offers:
		if offer is Dictionary and not bool(offer.get("unique", false)):
			random_offers.append(offer)
	offers.clear()
	offers.append_array(UniqueGladiatorManager.get_available_market_offers())
	offers.append_array(random_offers)
	market_changed.emit()


func _generate_offer(index: int) -> Dictionary:
	_serial += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system()) + _serial * 7919 + index * 131
	var role := "gladiator" if rng.randf() < 0.28 else "slave"
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
		"traits": _generate_offer_traits(rng)
	}
	offer["price"] = MarketValuation.offer_value(offer)
	return offer


func _generate_offer_traits(rng: RandomNumberGenerator) -> Array[String]:
	var candidates: Array[String] = []
	var trait_data_by_id: Dictionary = {}
	for raw_entry in DataRepository.traits:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		if str(entry.get("category", "")) != "normal":
			continue
		var trait_id := str(entry.get("id", ""))
		if trait_id.is_empty():
			continue
		candidates.append(trait_id)
		trait_data_by_id[trait_id] = entry
	candidates.sort()

	var selected: Array[String] = []
	while not candidates.is_empty() and selected.size() < 2:
		var candidate_index := rng.randi_range(0, candidates.size() - 1)
		var candidate_id := candidates[candidate_index]
		candidates.remove_at(candidate_index)
		if _traits_are_compatible(candidate_id, selected, trait_data_by_id):
			selected.append(candidate_id)
	return selected


func _traits_are_compatible(
	candidate_id: String, selected: Array[String], trait_data_by_id: Dictionary
) -> bool:
	var candidate: Dictionary = trait_data_by_id.get(candidate_id, {})
	var candidate_incompatibilities: Array = candidate.get("incompatible_with", [])
	for selected_id in selected:
		if candidate_incompatibilities.has(selected_id):
			return false
		var existing: Dictionary = trait_data_by_id.get(selected_id, {})
		if existing.get("incompatible_with", []).has(candidate_id):
			return false
	return true


func _generate_equipment_offer(recipe_id: String, index: int) -> Dictionary:
	_equipment_offer_serial += 1
	var recipe := EquipmentManager.get_recipe(recipe_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system()) + _equipment_offer_serial * 3571 + index * 197
	var quality_roll := rng.randf()
	var quality := "Común"
	if quality_roll < 0.08:
		quality = "Magistral"
	elif quality_roll < 0.30:
		quality = "Superior"
	var quality_multiplier := 1.0
	if quality == "Superior":
		quality_multiplier = 1.25
	elif quality == "Magistral":
		quality_multiplier = 1.55
	var base_value := int(recipe.get("denarii", 0)) + int(recipe.get("ore", 0)) * 4
	return {
		"id": "equipment_offer_%d" % _equipment_offer_serial,
		"recipe_id": recipe_id,
		"name": str(recipe.get("name", recipe_id)),
		"type": str(recipe.get("type", "weapon")),
		"slot": str(recipe.get("slot", EquipmentManager.get_item_slot(recipe))),
		"quality": quality,
		"power": int(recipe.get("power", 0)),
		"defense": int(recipe.get("defense", 0)),
		"tags": recipe.get("tags", []).duplicate(),
		"price": maxi(20, int(round(float(base_value) * quality_multiplier)))
	}


func recalculate_offer_price(offer_id: String) -> int:
	var offer := get_offer(offer_id)
	if offer.is_empty():
		return 0
	if bool(offer.get("unique", false)):
		return int(offer.get("price", 0))
	offer["price"] = MarketValuation.offer_value(offer)
	market_changed.emit()
	return int(offer["price"])


func buy_offer(offer_id: String) -> bool:
	var offer := get_offer(offer_id)
	var validation_error := _get_offer_purchase_error(offer)
	if not validation_error.is_empty():
		purchase_failed.emit(validation_error)
		return false
	var unique_id := str(offer.get("unique_gladiator_id", ""))
	var unique_status := (
		str(UniqueGladiatorManager.get_state(unique_id).get("status", ""))
		if not unique_id.is_empty()
		else ""
	)
	if not unique_id.is_empty() and unique_status not in ["initial_market", "market"]:
		purchase_failed.emit("Este gladiador único ya no está disponible.")
		sync_unique_offers()
		return false
	var price := int(offer.get("price", MarketValuation.offer_value(offer)))
	if not GameState.spend_denarii(price):
		purchase_failed.emit("No hay suficientes denarios.")
		return false
	var person_data := offer.duplicate(true)
	person_data.erase("price")
	if not unique_id.is_empty():
		person_data["id"] = unique_id
	var person = PERSON_SCRIPT.new(person_data)
	if not RosterManager.add_person(person):
		GameState.denarii += price
		GameState.resources_changed.emit()
		purchase_failed.emit("No se pudo incorporar al candidato.")
		return false
	var confirmed := true
	if not unique_id.is_empty():
		confirmed = (
			UniqueGladiatorManager.acquire_initial_gladiator(unique_id)
			if unique_status == "initial_market"
			else UniqueGladiatorManager.acquire_market_gladiator(unique_id)
		)
	if not confirmed:
		RosterManager.people.erase(person)
		GameState.denarii += price
		GameState.resources_changed.emit()
		RosterManager.roster_changed.emit()
		purchase_failed.emit("No se pudo confirmar la compra del gladiador único.")
		return false
	if unique_id.is_empty():
		offers.erase(offer)
	else:
		sync_unique_offers()
	purchase_completed.emit(person.display_name, price)
	market_changed.emit()
	return true


func _get_offer_purchase_error(offer: Dictionary) -> String:
	if CampaignManager.campaign_over:
		return "La campaña terminó. No se pueden realizar nuevas compras."
	if offer.is_empty():
		return "La oferta ya no está disponible."
	if not RosterManager.has_capacity():
		return "Los barracones están completos."
	return ""


func buy_equipment_offer(offer_id: String) -> bool:
	if CampaignManager.campaign_over:
		equipment_purchase_failed.emit("La campaña terminó. No se pueden realizar nuevas compras.")
		return false
	var offer := get_equipment_offer(offer_id)
	if offer.is_empty():
		equipment_purchase_failed.emit("La oferta de equipamiento ya no está disponible.")
		return false
	var price := int(offer.get("price", 0))
	if not GameState.spend_denarii(price):
		equipment_purchase_failed.emit("No hay suficientes denarios.")
		return false
	var purchased := EquipmentManager.add_market_item(offer)
	if purchased.is_empty():
		GameState.denarii += price
		GameState.resources_changed.emit()
		equipment_purchase_failed.emit("No se pudo incorporar el objeto al inventario.")
		return false
	equipment_offers.erase(offer)
	equipment_purchase_completed.emit(str(purchased.get("name", "Objeto")), price)
	equipment_market_changed.emit()
	return true


func get_offer(offer_id: String) -> Dictionary:
	for offer in offers:
		if str(offer.get("id", "")) == offer_id:
			return offer
	return {}


func get_offers() -> Array:
	return offers.duplicate(true)


func get_equipment_offer(offer_id: String) -> Dictionary:
	for offer in equipment_offers:
		if str(offer.get("id", "")) == offer_id:
			return offer
	return {}


func get_equipment_offers() -> Array[Dictionary]:
	return equipment_offers.duplicate(true)
