extends Node

const PersonScript = preload("res://scripts/entities/person.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var manager = GladiatorProgressionManager
    manager._load_catalogs()
    manager.records.clear()

    RosterManager.people.clear()
    var person = PersonScript.new({
        "id":"progression_test_gladiator",
        "name":"Test Gladiator",
        "role":"gladiator",
        "strength":5,
        "agility":5,
        "endurance":5,
        "intelligence":5,
        "technique":5,
        "health":50
    })
    RosterManager.people.append(person)

    var record: Dictionary = manager.ensure_record(person.id)
    assert(int(record.get("level", 0)) == 1, "A new gladiator must start at level 1")
    assert(int(record.get("skill_points", 0)) == 1, "A level 1 gladiator must arrive with one skill point")
    assert(record.get("abilities", {}).is_empty(), "A new gladiator must not know abilities")

    assert(manager.upgrade_ability(person.id, "precise_strike"), "The initial point must learn a basic ability")
    assert(manager.get_ability_level(person.id, "precise_strike") == 1, "The learned ability must be level I")
    assert(not manager.upgrade_ability(person.id, "precise_strike"), "An ability cannot improve without another point")

    record["skill_points"] = 1
    assert(manager.upgrade_ability(person.id, "precise_strike"), "A second point must improve the ability")
    assert(manager.get_ability_level(person.id, "precise_strike") == 2, "The ability must reach level II")
    record["skill_points"] = 1
    assert(not manager.upgrade_ability(person.id, "precise_strike"), "Ability level II must be the maximum")
    assert(not manager.upgrade_ability(person.id, "cast_net"), "Class abilities must stay locked before specialization")

    record["level"] = 3
    assert(manager.set_specialization(person.id, "retiarius"), "A level 3 gladiator must be able to specialize")
    assert(not manager.set_specialization(person.id, "murmillo"), "A chosen specialization must be permanent")
    assert(manager.upgrade_ability(person.id, "cast_net"), "The matching class ability must unlock after specialization")

    var before := {
        "strength":person.strength,
        "agility":person.agility,
        "endurance":person.endurance,
        "intelligence":person.intelligence,
        "technique":person.technique,
        "health":person.health
    }
    manager._apply_level_growth(person.id, "retiarius")
    assert(person.strength == int(before.strength) + 1, "Retiarius growth must add 1 strength")
    assert(person.agility == int(before.agility) + 3, "Retiarius growth must add 3 agility")
    assert(person.endurance == int(before.endurance) + 1, "Retiarius growth must add 1 endurance")
    assert(person.intelligence == int(before.intelligence) + 2, "Retiarius growth must add 2 intelligence")
    assert(person.technique == int(before.technique) + 3, "Retiarius growth must add 3 technique")
    assert(person.health == int(before.health) + 10, "Retiarius growth must add 10 health")

    assert(manager.set_tactical_plan(person.id, [
        {"ability_id":"cast_net", "condition":"opening"},
        {"ability_id":"precise_strike", "condition":"target_vulnerable"}
    ]), "A tactical plan must accept learned abilities")
    assert(manager.get_tactical_plan(person.id).size() == 2, "The tactical plan must preserve its valid orders")

    record["level"] = 9
    record["experience"] = manager.get_experience_required(9) * 5
    manager._resolve_level_ups(person.id, record)
    assert(int(record.get("level", 0)) == 10, "The demo progression must stop at level 10")
    assert(int(record.get("experience", -1)) == 0, "Experience must stop accumulating at the demo cap")

    print("Gladiator progression demo tests passed")
    get_tree().quit(0)
