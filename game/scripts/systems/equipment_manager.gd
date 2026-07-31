extends Node

signal inventory_changed
signal craft_completed(item_name: String, cost_ore: int, cost_denarii: int)
signal craft_failed(reason: String)
signal equipment_changed(person_id: String)
signal equipment_failed(reason: String)

const RECIPES := {
    "gladius": {"name":"Gladius","type":"weapon","forge_level":1,"ore":8,"denarii":45,"power":12,"tags":["weapon","blade","single_weapon"]},
    "spear": {"name":"Lanza de arena","type":"weapon","forge_level":1,"ore":10,"denarii":50,"power":10,"tags":["weapon","spear","single_weapon"]},
    "mace": {"name":"Maza pesada","type":"weapon","forge_level":2,"ore":14,"denarii":75,"power":15,"tags":["weapon","blunt","single_weapon"]},
    "retiarius_kit": {"name":"Red y tridente","type":"weapon","forge_level":1,"ore":12,"denarii":65,"power":10,"tags":["weapon","spear","net","retiarius_kit"]},
    "dual_blades": {"name":"Par de espadas cortas","type":"weapon","forge_level":2,"ore":16,"denarii":85,"power":14,"tags":["weapon","blade","dual_blades"]},
    "leather_armor": {"name":"Armadura de cuero","type":"armor","forge_level":1,"ore":5,"denarii":40,"defense":6,"tags":["armor","light_armor"]},
    "mail_armor": {"name":"Cota de malla","type":"armor","forge_level":2,"ore":16,"denarii":90,"defense":11,"tags":["armor","heavy_armor"]},
    "tower_shield": {"name":"Escudo de torre","type":"shield","forge_level":3,"ore":20,"denarii":120,"defense":15,"tags":["shield","large_shield"]}
}

const UNIVERSAL_TECHNIQUES: Array[String] = ["basic_attack", "precise_strike", "feint", "opportunity_strike", "throw_sand"]

var inventory: Array[Dictionary] = []
var serial: int = 0

func get_recipe_ids() -> Array[String]:
    var result: Array[String] = []
    for recipe_id in RECIPES.keys():
        result.append(str(recipe_id))
    return result

func get_recipe(recipe_id: String) -> Dictionary:
    var data: Dictionary = RECIPES.get(recipe_id, {}).duplicate(true)
    data["id"] = recipe_id
    data["unlocked"] = EstateManager.get_forge_level() >= int(data.get("forge_level", 99))
    return data

func craft(recipe_id: String) -> bool:
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
    item["equipped_by"] = ""
    inventory.append(item)
    GameState.resources_changed.emit()
    inventory_changed.emit()
    craft_completed.emit(str(recipe.get("name", recipe_id)), ore_cost, denarii_cost)
    return true

func equip_item(person_id: String, item_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    var item := get_item(item_id)
    if person == null or item.is_empty():
        equipment_failed.emit("Personaje u objeto inválido.")
        return false
    if person.role != "gladiator":
        equipment_failed.emit("Solo los gladiadores pueden equiparse.")
        return false
    if not str(item.get("equipped_by", "")).is_empty() and str(item.get("equipped_by", "")) != person_id:
        equipment_failed.emit("Ese objeto ya está equipado por otro gladiador.")
        return false
    var item_type := str(item.get("type", ""))
    var previous_id := ""
    match item_type:
        "weapon": previous_id = person.equipped_weapon_id; person.equipped_weapon_id = item_id
        "armor": previous_id = person.equipped_armor_id; person.equipped_armor_id = item_id
        "shield": previous_id = person.equipped_shield_id; person.equipped_shield_id = item_id
        _:
            equipment_failed.emit("Tipo de objeto no equipable.")
            return false
    if not previous_id.is_empty() and previous_id != item_id:
        var previous := get_item(previous_id)
        if not previous.is_empty():
            previous["equipped_by"] = ""
    item["equipped_by"] = person_id
    inventory_changed.emit()
    equipment_changed.emit(person_id)
    return true

func unequip_slot(person_id: String, slot: String) -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null:
        equipment_failed.emit("Personaje inválido.")
        return false
    var item_id := ""
    match slot:
        "weapon": item_id = person.equipped_weapon_id; person.equipped_weapon_id = ""
        "armor": item_id = person.equipped_armor_id; person.equipped_armor_id = ""
        "shield": item_id = person.equipped_shield_id; person.equipped_shield_id = ""
        _:
            equipment_failed.emit("Ranura inválida.")
            return false
    if not item_id.is_empty():
        var item := get_item(item_id)
        if not item.is_empty():
            item["equipped_by"] = ""
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

func get_equipped_stats(person) -> Dictionary:
    var stats := {"power":0, "defense":0}
    for item_id in [person.equipped_weapon_id, person.equipped_armor_id, person.equipped_shield_id]:
        if item_id.is_empty():
            continue
        var item := get_item(item_id)
        var multiplier := _quality_multiplier(str(item.get("quality", "Común")))
        stats.power += int(round(int(item.get("power", 0)) * multiplier))
        stats.defense += int(round(int(item.get("defense", 0)) * multiplier))
    return stats

func get_equipped_loadout(person) -> Dictionary:
    if person == null:
        return {"weapon":"", "armor":"", "shield":"", "weapon_name":"Ninguno", "armor_name":"Ninguna", "shield_name":"Ninguno", "tags":[]}
    var weapon := get_item(person.equipped_weapon_id)
    var armor := get_item(person.equipped_armor_id)
    var shield := get_item(person.equipped_shield_id)
    return {
        "weapon":str(weapon.get("recipe_id", "")),
        "armor":str(armor.get("recipe_id", "")),
        "shield":str(shield.get("recipe_id", "")),
        "weapon_name":get_item_name(person.equipped_weapon_id),
        "armor_name":get_item_name(person.equipped_armor_id),
        "shield_name":get_item_name(person.equipped_shield_id),
        "tags":get_equipped_tags(person)
    }

func get_equipped_tags(person) -> Array[String]:
    var tags: Array[String] = []
    if person == null:
        return tags
    for item_id in [person.equipped_weapon_id, person.equipped_armor_id, person.equipped_shield_id]:
        if item_id.is_empty():
            continue
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
            "shield": labels.append("un escudo")
            "net": labels.append("una red y tridente")
            "dual_blades": labels.append("un par de espadas cortas")
            _: labels.append(str(raw_tag).replace("_", " "))
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
        "Superior": return 1.15
        "Magistral": return 1.35
        _: return 1.0

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
