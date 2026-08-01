extends Node

const PersonScript = preload("res://scripts/entities/person.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    GladiatorProgressionManager._load_catalogs()
    GladiatorProgressionManager.records.clear()
    RosterManager.people.clear()
    EquipmentManager.inventory.clear()

    var person = PersonScript.new({
        "id":"equipment_requirement_gladiator",
        "name":"Equipment Test",
        "role":"gladiator",
        "strength":5,
        "agility":5,
        "endurance":5,
        "intelligence":5,
        "technique":5,
        "health":50
    })
    RosterManager.people.append(person)

    var record := GladiatorProgressionManager.ensure_record(person.id)
    record["level"] = 3
    record["specialization"] = "murmillo"
    record["abilities"] = {"shield_charge":1, "precise_strike":1}
    record["tactical_plan"] = [
        {"ability_id":"shield_charge", "condition":"always"},
        {"ability_id":"precise_strike", "condition":"always"}
    ]

    var shield_charge: Dictionary = GladiatorProgressionManager.abilities.get("shield_charge", {})
    assert(not EquipmentManager.can_use_ability(person, shield_charge), "Embate del escudo must be blocked without a shield")
    EquipmentAbilityGuard._sanitize_person_record(person.id)
    assert(GladiatorProgressionManager.get_tactical_plan(person.id).size() == 1, "An incompatible class ability must be removed from the tactical plan")
    assert(str(GladiatorProgressionManager.get_tactical_plan(person.id)[0].get("ability_id", "")) == "precise_strike", "Universal learned abilities must remain available")

    EquipmentManager.inventory.append({
        "id":"tower_shield_test",
        "recipe_id":"tower_shield",
        "name":"Escudo de torre",
        "type":"shield",
        "defense":15,
        "tags":["shield","large_shield"],
        "quality":"Común",
        "equipped_by":person.id
    })
    person.equipped_shield_id = "tower_shield_test"
    assert(EquipmentManager.can_use_ability(person, shield_charge), "Embate del escudo must unlock with a shield equipped")

    var retiarius_kit := EquipmentManager.get_recipe("retiarius_kit")
    assert(retiarius_kit.get("tags", []).has("net"), "The retiarius kit must provide the net tag")
    var dual_blades := EquipmentManager.get_recipe("dual_blades")
    assert(dual_blades.get("tags", []).has("dual_blades"), "The paired blades item must provide the dual_blades tag")

    var cast_net: Dictionary = GladiatorProgressionManager.abilities.get("cast_net", {})
    var dance: Dictionary = GladiatorProgressionManager.abilities.get("dance_of_two_blades", {})
    assert(EquipmentManager.get_ability_requirement(cast_net).contains("red"), "Red de captura must explain its equipment requirement")
    assert(EquipmentManager.get_ability_requirement(dance).contains("espadas"), "Danza de dos filos must explain its equipment requirement")

    print("Equipment ability requirement tests passed")
    get_tree().quit(0)
