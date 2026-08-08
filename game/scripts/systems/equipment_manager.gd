extends Node

signal inventory_changed
signal craft_completed(item_name: String, cost_ore: int, cost_denarii: int)
signal craft_failed(reason: String)
signal equipment_changed(person_id: String)
signal equipment_failed(reason: String)

const EQUIPMENT_SLOTS := {
	"head": "Casco",
	"torso": "Torso",
	"right_hand": "Mano derecha",
	"left_hand": "Mano izquierda",
	"lower_body": "Parte inferior",
	"accessory": "Accesorio",
	"mount": "Montura"
}
const EQUIPMENT_SLOT_ORDER: Array[String] = [
	"head", "torso", "right_hand", "left_hand", "lower_body", "accessory", "mount"
]
const LEGACY_SLOT_ALIASES := {"weapon": "right_hand", "armor": "torso", "shield": "left_hand"}

var RECIPES: Dictionary = {}

const UNIVERSAL_TECHNIQUES: Array[String] = [
	"basic_attack", "precise_strike", "feint", "opportunity_strike", "throw_sand"
]

var inventory: Array[Dictionary] = []
var serial: int = 0


func _ready() -> void:
	_ensure_recipes_loaded()


func _ensure_recipes_loaded() -> void:
	if not RECIPES.is_empty():
		return
	for raw_entry in DataRepository.weapons:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var recipe_id := str(entry.get("id", ""))
		if recipe_id.is_empty() or RECIPES.has(recipe_id):
			continue
		var recipe := entry.duplicate(true)
		recipe.erase("id")
		RECIPES[recipe_id] = recipe


func get_recipe_ids() -> Array[String]:
	_ensure_recipes_loaded()
	var result: Array[String] = []
	for recipe_id in RECIPES.keys():
		result.append(str(recipe_id))
	result.sort()
	return result


func get_recipe(recipe_id: String) -> Dictionary:
	_ensure_recipes_loaded()
	var data: Dictionary = RECIPES.get(recipe_id, {}).duplicate(true)
	data["id"] = recipe_id
	data["unlocked"] = EstateManager.get_forge_level() >= int(data.get("forge_level", 99))
	data["slot"] = get_item_slot(data)
	return data


func get_slot_ids() -> Array[String]:
	return EQUIPMENT_SLOT_ORDER.duplicate()


func get_slot_label(slot_id: String) -> String:
	return str(EQUIPMENT_SLOTS.get(canonical_slot_id(slot_id), slot_id.capitalize()))


func canonical_slot_id(slot_id: String) -> String:
	var canonical := str(LEGACY_SLOT_ALIASES.get(slot_id, slot_id))
	return canonical if EQUIPMENT_SLOTS.has(canonical) else ""


func get_slot_icon_asset(slot_id: String) -> String:
	match canonical_slot_id(slot_id):
		"head":
			return "ui/equipment/equipment_head_helmet"
		"torso":
			return "ui/equipment/equipment_torso_armor"
		"right_hand":
			return "ui/equipment/equipment_weapon_sword"
		"left_hand":
			return "ui/equipment/equipment_shield"
		"lower_body":
			return "ui/equipment/equipment_feet_boots"
		"accessory":
			return "ui/equipment/equipment_additional_net"
		"mount":
			return "ui/icons/ui_icon_circle_brown"
		_:
			return ""


func craft(recipe_id: String) -> bool:
	_ensure_recipes_loaded()
	if CampaignManager.campaign_over:
		craft_failed.emit("La campaña terminó. La forja está disponible solo para consulta.")
		return false
	if not RECIPES.has(recipe_id):
		craft_failed.emit("Receta desconocida.")
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	var required_level := int(recipe.get("forge_level", 1))
	if EstateManager.get_forge_level() < required_level:
		craft_failed.emit("La forja no tiene el nivel necesario.")
		return false
	var ore_cost := int(recipe.get("ore", 0))
	var denarii_cost := int(recipe.get("denarii", 0))
	if GameState.ore < ore_cost:
		craft_failed.emit("No hay suficiente mineral.")
		return false
	if not GameState.spend_denarii(denarii_cost):
		craft_failed.emit("No hay suficientes denarios.")
		return false
	GameState.ore -= ore_cost
	serial += 1
	var item := recipe.duplicate(true)
	item["id"] = "%s_%d" % [recipe_id, serial]
	item["recipe_id"] = recipe_id
	item["quality"] = _roll_quality()
	item["slot"] = get_item_slot(item)
	item["equipped_by"] = ""
	item["equipped_slot"] = ""
	inventory.append(item)
	GameState.resources_changed.emit()
	inventory_changed.emit()
	craft_completed.emit(str(recipe.get("name", recipe_id)), ore_cost, denarii_cost)
	return true


func add_market_item(offer: Dictionary) -> Dictionary:
	if offer.is_empty():
		return {}
	var recipe_id := str(offer.get("recipe_id", "market_item"))
	serial += 1
	var item := {
		"id": "%s_market_%d" % [recipe_id, serial],
		"recipe_id": recipe_id,
		"name": str(offer.get("name", "Objeto de mercado")),
		"type": str(offer.get("type", "weapon")),
		"slot": str(offer.get("slot", "")),
		"quality": str(offer.get("quality", "Común")),
		"power": int(offer.get("power", 0)),
		"defense": int(offer.get("defense", 0)),
		"tags": offer.get("tags", []).duplicate(),
		"equipped_by": "",
		"equipped_slot": ""
	}
	item["slot"] = get_item_slot(item)
	inventory.append(item)
	inventory_changed.emit()
	return item.duplicate(true)


func get_item_slot(item: Dictionary) -> String:
	var explicit := canonical_slot_id(str(item.get("slot", item.get("equipped_slot", ""))))
	if not explicit.is_empty():
		return explicit
	match str(item.get("type", "")):
		"weapon":
			return "right_hand"
		"armor":
			return "torso"
		"shield":
			return "left_hand"
		"helmet", "head":
			return "head"
		"lower_body", "boots", "greaves":
			return "lower_body"
		"accessory", "consumable", "antidote", "cheat_item":
			return "accessory"
		"mount":
			return "mount"
		_:
			return ""


func is_item_compatible_with_slot(item: Dictionary, slot_id: String) -> bool:
	var canonical := canonical_slot_id(slot_id)
	if canonical.is_empty() or canonical == "mount":
		return false
	return get_item_slot(item) == canonical


func equip_item(person_id: String, item_id: String) -> bool:
	var item := get_item(item_id)
	if item.is_empty():
		equipment_failed.emit("Objeto inválido.")
		return false
	return equip_item_to_slot(person_id, item_id, get_item_slot(item))


func equip_item_to_slot(person_id: String, item_id: String, slot_id: String) -> bool:
	var person = RosterManager.get_person(person_id)
	var item := get_item(item_id)
	var canonical := canonical_slot_id(slot_id)
	if person == null or item.is_empty():
		equipment_failed.emit("Personaje u objeto inválido.")
		return false
	if str(person.role) != "gladiator":
		equipment_failed.emit("Solo los gladiadores pueden equiparse.")
		return false
	if canonical == "mount":
		equipment_failed.emit("Las monturas estarán disponibles próximamente.")
		return false
	if not is_item_compatible_with_slot(item, canonical):
		equipment_failed.emit(
			"El objeto no corresponde a la ranura %s." % get_slot_label(canonical)
		)
		return false
	var equipped_person_id := str(item.get("equipped_by", ""))
	if not equipped_person_id.is_empty() and equipped_person_id != person_id:
		equipment_failed.emit("Ese objeto ya está equipado por otro gladiador.")
		return false

	_rebuild_person_slots(person)
	var previous_slot := canonical_slot_id(str(item.get("equipped_slot", "")))
	if (
		equipped_person_id == person_id
		and not previous_slot.is_empty()
		and previous_slot != canonical
	):
		person.set_equipped_item_id(previous_slot, "")

	var previous_id: String = str(person.get_equipped_item_id(canonical))
	if not previous_id.is_empty() and previous_id != item_id:
		var previous := get_item(previous_id)
		if not previous.is_empty():
			previous["equipped_by"] = ""
			previous["equipped_slot"] = ""

	person.set_equipped_item_id(canonical, item_id)
	item["slot"] = canonical
	item["equipped_by"] = person_id
	item["equipped_slot"] = canonical
	inventory_changed.emit()
	equipment_changed.emit(person_id)
	return true


func unequip_slot(person_id: String, slot: String) -> bool:
	return unequip_equipment_slot(person_id, canonical_slot_id(slot))


func unequip_equipment_slot(person_id: String, slot_id: String) -> bool:
	var person = RosterManager.get_person(person_id)
	var canonical := canonical_slot_id(slot_id)
	if person == null:
		equipment_failed.emit("Personaje inválido.")
		return false
	if canonical.is_empty():
		equipment_failed.emit("Ranura inválida.")
		return false
	if canonical == "mount":
		equipment_failed.emit("Las monturas todavía no están habilitadas.")
		return false
	_rebuild_person_slots(person)
	var item_id: String = str(person.get_equipped_item_id(canonical))
	person.set_equipped_item_id(canonical, "")
	if not item_id.is_empty():
		var item := get_item(item_id)
		if not item.is_empty():
			item["equipped_by"] = ""
			item["equipped_slot"] = ""
	inventory_changed.emit()
	equipment_changed.emit(person_id)
	return true


func get_available_items(item_type: String, person_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in inventory:
		if str(item.get("type", "")) != item_type:
			continue
		var equipped_person_id := str(item.get("equipped_by", ""))
		if equipped_person_id.is_empty() or equipped_person_id == person_id:
			result.append(item.duplicate(true))
	return result


func get_available_items_for_slot(slot_id: String, person_id: String = "") -> Array[Dictionary]:
	var canonical := canonical_slot_id(slot_id)
	var result: Array[Dictionary] = []
	if canonical.is_empty() or canonical == "mount":
		return result
	for item in inventory:
		if not is_item_compatible_with_slot(item, canonical):
			continue
		var equipped_person_id := str(item.get("equipped_by", ""))
		if equipped_person_id.is_empty() or equipped_person_id == person_id:
			var copy := item.duplicate(true)
			copy["slot"] = canonical
			result.append(copy)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary): return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result


func get_item(item_id: String) -> Dictionary:
	for item in inventory:
		if str(item.get("id", "")) == item_id:
			return item
	return {}


func get_item_name(item_id: String) -> String:
	if item_id.is_empty():
		return "Ninguno"
	var item := get_item(item_id)
	if item.is_empty():
		return "Ninguno"
	return "%s (%s)" % [item.get("name", "Objeto"), item.get("quality", "Común")]


func get_equipped_slots(person) -> Dictionary:
	if person == null:
		var empty: Dictionary = {}
		for slot_id in EQUIPMENT_SLOT_ORDER:
			empty[slot_id] = ""
		return empty
	_rebuild_person_slots(person)
	return person.get_equipped_slots()


func _rebuild_person_slots(person) -> void:
	if person == null:
		return
	person.synchronize_legacy_equipment()
	for item in inventory:
		if str(item.get("equipped_by", "")) != str(person.id):
			continue
		var slot_id := canonical_slot_id(str(item.get("equipped_slot", "")))
		if slot_id.is_empty():
			slot_id = get_item_slot(item)
			item["equipped_slot"] = slot_id
		if slot_id.is_empty() or slot_id == "mount":
			continue
		var current_id: String = str(person.get_equipped_item_id(slot_id))
		if current_id.is_empty() or current_id == str(item.get("id", "")):
			person.set_equipped_item_id(slot_id, str(item.get("id", "")))


func get_equipped_stats(person) -> Dictionary:
	var stats := {"power": 0, "defense": 0}
	var seen: Dictionary = {}
	for item_id_value in get_equipped_slots(person).values():
		var item_id := str(item_id_value)
		if item_id.is_empty() or seen.has(item_id):
			continue
		seen[item_id] = true
		var item := get_item(item_id)
		var multiplier := _quality_multiplier(str(item.get("quality", "Común")))
		stats.power += int(round(int(item.get("power", 0)) * multiplier))
		stats.defense += int(round(int(item.get("defense", 0)) * multiplier))
	return stats


func get_equipped_loadout(person) -> Dictionary:
	if person == null:
		return {
			"weapon": "",
			"armor": "",
			"shield": "",
			"weapon_name": "Ninguno",
			"armor_name": "Ninguna",
			"shield_name": "Ninguno",
			"slots": get_equipped_slots(null),
			"slot_names": {},
			"tags": []
		}
	var slots := get_equipped_slots(person)
	var weapon := get_item(str(slots.get("right_hand", "")))
	var armor := get_item(str(slots.get("torso", "")))
	var shield := get_item(str(slots.get("left_hand", "")))
	var slot_names: Dictionary = {}
	for slot_id in EQUIPMENT_SLOT_ORDER:
		var item_id := str(slots.get(slot_id, ""))
		slot_names[slot_id] = "Próximamente" if slot_id == "mount" else get_item_name(item_id)
	return {
		"weapon": str(weapon.get("recipe_id", "")),
		"armor": str(armor.get("recipe_id", "")),
		"shield": str(shield.get("recipe_id", "")),
		"weapon_name": get_item_name(str(slots.get("right_hand", ""))),
		"armor_name": get_item_name(str(slots.get("torso", ""))),
		"shield_name": get_item_name(str(slots.get("left_hand", ""))),
		"slots": slots,
		"slot_names": slot_names,
		"tags": get_equipped_tags(person)
	}


func get_equipped_tags(person) -> Array[String]:
	var tags: Array[String] = []
	if person == null:
		return tags
	var seen: Dictionary = {}
	for item_id_value in get_equipped_slots(person).values():
		var item_id := str(item_id_value)
		if item_id.is_empty() or seen.has(item_id):
			continue
		seen[item_id] = true
		var item := get_item(item_id)
		for raw_tag in item.get("tags", []):
			var tag := str(raw_tag)
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
	return tags


func can_use_ability(person, ability: Dictionary) -> bool:
	if person == null or ability.is_empty():
		return false
	var required_tags: Array = ability.get("required_equipment_tags", [])
	if required_tags.is_empty():
		return true
	var equipped_tags := get_equipped_tags(person)
	for raw_tag in required_tags:
		if not equipped_tags.has(str(raw_tag)):
			return false
	return true


func can_use_ability_id(person, ability_id: String) -> bool:
	var ability: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
	return can_use_ability(person, ability)


func get_ability_requirement(ability: Dictionary) -> String:
	var required_tags: Array = ability.get("required_equipment_tags", [])
	if required_tags.is_empty():
		return "Sin requisito especial de equipo."
	var labels: Array[String] = []
	for raw_tag in required_tags:
		match str(raw_tag):
			"shield":
				labels.append("un escudo")
			"net":
				labels.append("una red y tridente")
			"dual_blades":
				labels.append("un par de espadas cortas")
			_:
				labels.append(str(raw_tag).replace("_", " "))
	return "Requiere %s equipado." % " y ".join(labels)


func get_allowed_combat_techniques(person) -> Array[String]:
	var allowed: Array[String] = ["basic_attack"]
	if person == null:
		return allowed
	for ability_id in GladiatorProgressionManager.get_available_ability_ids(person.id):
		var ability: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
		if can_use_ability(person, ability):
			allowed.append(ability_id)
	return allowed


func get_technique_requirement(technique_id: String) -> String:
	if technique_id == "basic_attack":
		return "Disponible sin requisito de equipo."
	return get_ability_requirement(GladiatorProgressionManager.abilities.get(technique_id, {}))


func _quality_multiplier(quality: String) -> float:
	match quality:
		"Superior":
			return 1.15
		"Magistral":
			return 1.35
		_:
			return 1.0


func _roll_quality() -> String:
	var roll := randf()
	var forge_level := EstateManager.get_forge_level()
	if roll < 0.04 * forge_level:
		return "Magistral"
	if roll < 0.15 + 0.05 * forge_level:
		return "Superior"
	return "Común"


func get_inventory() -> Array:
	return inventory.duplicate(true)
