extends Node

signal inventory_changed
signal craft_completed(item_name: String, cost_ore: int, cost_denarii: int)
signal craft_failed(reason: String)
signal equipment_changed(person_id: String)
signal equipment_failed(reason: String)

const RECIPES := {
    "gladius": {"name":"Gladius","type":"weapon","forge_level":1,"ore":8,"denarii":45,"power":12},
    "spear": {"name":"Lanza de arena","type":"weapon","forge_level":1,"ore":10,"denarii":50,"power":10},
    "mace": {"name":"Maza pesada","type":"weapon","forge_level":2,"ore":14,"denarii":75,"power":15},
    "leather_armor": {"name":"Armadura de cuero","type":"armor","forge_level":1,"ore":5,"denarii":40,"defense":6},
    "mail_armor": {"name":"Cota de malla","type":"armor","forge_level":2,"ore":16,"denarii":90,"defense":11},
    "tower_shield": {"name":"Escudo de torre","type":"shield","forge_level":3,"ore":20,"denarii":120,"defense":15}
}

const UNIVERSAL_TECHNIQUES: Array[String] = ["basic_attack", "guard", "feint", "warcry", "throw_sand"]
const WEAPON_TECHNIQUES := {
    "gladius": ["lunge", "disarm", "execute"],
    "spear": ["lunge", "disarm", "execute"],
    "mace": ["sunder", "disarm", "execute"]
}

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
        if not previous.is_empty(): previous["equipped_by"] = ""
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
        if not item.is_empty(): item["equipped_by"] = ""
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
    var stats := {"power": 0, "defense": 0}
    for item_id in [person.equipped_weapon_id, person.equipped_armor_id, person.equipped_shield_id]:
        if item_id.is_empty(): continue
        var item := get_item(item_id)
        var multiplier := _quality_multiplier(str(item.get("quality", "Común")))
        stats.power += int(round(int(item.get("power", 0)) * multiplier))
        stats.defense += int(round(int(item.get("defense", 0)) * multiplier))
    return stats

func get_equipped_loadout(person) -> Dictionary:
    if person == null:
        return {"weapon":"", "armor":"", "shield":"", "weapon_name":"Ninguno", "armor_name":"Ninguna", "shield_name":"Ninguno"}
    var weapon := get_item(person.equipped_weapon_id)
    var armor := get_item(person.equipped_armor_id)
    var shield := get_item(person.equipped_shield_id)
    return {
        "weapon": str(weapon.get("recipe_id", "")),
        "armor": str(armor.get("recipe_id", "")),
        "shield": str(shield.get("recipe_id", "")),
        "weapon_name": get_item_name(person.equipped_weapon_id),
        "armor_name": get_item_name(person.equipped_armor_id),
        "shield_name": get_item_name(person.equipped_shield_id)
    }

func get_allowed_combat_techniques(person) -> Array[String]:
    var allowed: Array[String] = UNIVERSAL_TECHNIQUES.duplicate()
    if person == null:
        return allowed
    var loadout := get_equipped_loadout(person)
    var weapon_id := str(loadout.get("weapon", ""))
    for technique in WEAPON_TECHNIQUES.get(weapon_id, []):
        if not allowed.has(str(technique)):
            allowed.append(str(technique))
    if not str(loadout.get("shield", "")).is_empty() and not allowed.has("shield_bash"):
        allowed.append("shield_bash")
    return allowed

func get_technique_requirement(technique_id: String) -> String:
    match technique_id:
        "shield_bash": return "Requiere un escudo equipado."
        "lunge": return "Requiere gladius o lanza."
        "sunder": return "Requiere una maza pesada."
        "disarm", "execute": return "Requiere un arma equipada."
        _: return "Disponible sin requisito de equipo."

func _quality_multiplier(quality: String) -> float:
    match quality:
        "Superior": return 1.15
        "Magistral": return 1.35
        _: return 1.0

func _roll_quality() -> String:
    var roll := randf()
    var forge_level := EstateManager.get_forge_level()
    if roll < 0.04 * forge_level: return "Magistral"
    if roll < 0.15 + 0.05 * forge_level: return "Superior"
    return "Común"

func get_inventory() -> Array:
    return inventory.duplicate(true)