extends Node

const PersonScript = preload("res://scripts/entities/person.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    GladiatorProgressionManager._load_catalogs()
    GladiatorProgressionManager.records.clear()
    RosterManager.people.clear()

    var person = PersonScript.new({
        "id":"migration_v13_gladiator",
        "name":"Migration Test",
        "role":"gladiator",
        "traits":["arena_lover", "protector", "dreamer"],
        "applied_trait_effects":["dreamer"],
        "technique":9,
        "health":71
    })
    RosterManager.people.append(person)

    var serialized: Dictionary = SaveManager._serialize_person(person)
    assert(int(serialized.get("technique", 0)) == 9, "Technique must persist in save v13")
    assert(int(serialized.get("health", 0)) == 71, "Health must persist in save v13")
    assert(serialized.get("applied_trait_effects", []).has("dreamer"), "Applied permanent trait effects must persist")

    var restored = SaveManager._deserialize_person(serialized)
    assert(restored.traits.has("dreamer"), "Permanent traits must survive deserialization")
    assert(restored.applied_trait_effects.has("dreamer"), "Permanent effects must not be applied twice after loading")

    var old_offer := {
        "id":"old_offer",
        "name":"Old Recruit",
        "role":"gladiator",
        "strength":6,
        "agility":6,
        "endurance":6,
        "intelligence":6,
        "traits":["protector", "protector", "arena_lover"],
        "price":1
    }
    var migrated_offer: Dictionary = SaveManager._migrate_market_offer(old_offer)
    assert(int(migrated_offer.get("technique", 0)) == 5, "Old market offers must receive default technique")
    assert(int(migrated_offer.get("health", 0)) == 50, "Old market offers must receive default health")
    assert(migrated_offer.get("traits", []).size() == 2, "Old offers must keep two unique origin traits")
    assert(int(migrated_offer.get("price", 0)) > 1, "Old offer prices must be recalculated")

    var migrated_record: Dictionary = GladiatorProgressionManager._migrate_record({
        "level":4,
        "specialization":"thraex",
        "technique_points":9,
        "techniques":["precise_strike", "iron_guard", "deep_reserves"],
        "tactical_plan":[
            {"ability_id":"feint", "condition":"target_defending"},
            {"ability_id":"throw_sand", "condition":"after_dodge_or_block"}
        ]
    }, person.id)
    assert(str(migrated_record.get("specialization", "")) == "dimachaerus", "Thraex must migrate to Dimachaerus")
    assert(not migrated_record.has("technique_points"), "Legacy technique points must be removed")
    assert(not migrated_record.has("techniques"), "Legacy technique lists must be removed")
    assert(int(migrated_record.get("skill_points", -1)) == 1, "Available points must equal level minus learned ranks")
    assert(int(migrated_record.get("abilities", {}).get("feint", 0)) == 1, "Iron Guard must migrate to Feint")
    assert(str(migrated_record.get("tactical_plan", [])[0].get("condition", "")) == "target_guarding", "Old defending condition must migrate")
    assert(str(migrated_record.get("tactical_plan", [])[1].get("condition", "")) == "after_defense", "Old defense reaction condition must migrate")

    GladiatorProgressionManager.records[person.id] = {
        "level":2,
        "experience":0,
        "specialization":"gladiator",
        "skill_points":0,
        "abilities":{"precise_strike":1},
        "tactical_plan":[]
    }
    assert(not GladiatorProgressionManager.set_tactical_plan(person.id, [
        {"ability_id":"unknown", "condition":"always"}
    ]), "Malformed plans must be rejected atomically")
    assert(GladiatorProgressionManager.get_tactical_plan(person.id).is_empty(), "Rejected plans must not replace the current plan")
    assert(GladiatorProgressionManager.set_tactical_plan(person.id, [
        {"ability_id":"precise_strike", "condition":"target_defending"}
    ]), "Known legacy condition aliases must remain load-compatible")
    assert(str(GladiatorProgressionManager.get_tactical_plan(person.id)[0].condition) == "target_guarding", "Stored plans must use canonical conditions")

    var old_battle_config := {
        "energy_rule":"conserve",
        "techniques":["basic_attack", "guard"],
        "tactical_plan":[{"ability_id":"precise_strike", "condition":"target_defending"}]
    }
    var migrated_config: Dictionary = SaveManager._migrate_battle_config(old_battle_config)
    assert(not migrated_config.has("techniques"), "Legacy combat technique loadouts must be removed")
    assert(str(migrated_config.get("tactical_plan", [])[0].condition) == "target_guarding", "Battle config conditions must migrate")

    print("Save v13 and progression migration tests passed")
    get_tree().quit(0)
