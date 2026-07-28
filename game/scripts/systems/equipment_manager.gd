extends Node

signal inventory_changed
signal craft_completed(item_name: String, cost_ore: int, cost_denarii: int)
signal craft_failed(reason: String)

const RECIPES := {
    "gladius": {"name":"Gladius","type":"weapon","forge_level":1,"ore":8,"denarii":45,"power":12},
    "spear": {"name":"Lanza de arena","type":"weapon","forge_level":1,"ore":10,"denarii":50,"power":10},
    "mace": {"name":"Maza pesada","type":"weapon","forge_level":2,"ore":14,"denarii":75,"power":15},
    "leather_armor": {"name":"Armadura de cuero","type":"armor","forge_level":1,"ore":5,"denarii":40,"defense":6},
    "mail_armor": {"name":"Cota de malla","type":"armor","forge_level":2,"ore":16,"denarii":90,"defense":11},
    "tower_shield": {"name":"Escudo de torre","type":"shield","forge_level":3,"ore":20,"denarii":120,"defense":15}
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
    inventory.append(item)
    GameState.resources_changed.emit()
    inventory_changed.emit()
    craft_completed.emit(str(recipe.get("name", recipe_id)), ore_cost, denarii_cost)
    return true

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
