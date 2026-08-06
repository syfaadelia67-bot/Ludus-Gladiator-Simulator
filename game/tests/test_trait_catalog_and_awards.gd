extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

func _ready() -> void:
    var origin_ids := TraitManager.get_origin_trait_ids()
    var obtainable_ids := TraitManager.get_obtainable_trait_ids()
    assert(origin_ids.size() == 8)
    assert(obtainable_ids.size() == 14)
    assert(obtainable_ids.has("dreamer"))
    assert(obtainable_ids.has("encouraging"))

    var gladiator = PERSON_SCRIPT.new({
        "id": "trait_contract_gladiator",
        "name": "Gladiador de contrato",
        "origin": "Roma",
        "role": "gladiator",
        "strength": 7,
        "agility": 6,
        "endurance": 8,
        "intelligence": 5,
        "technique": 6,
        "health": 50,
        "traits": []
    })
    assert(RosterManager.add_person(gladiator))
    TraitManager.ensure_gladiator_origin_traits(gladiator)

    var origin_count := 0
    for trait_id in gladiator.traits:
        if str(TraitManager.get_trait(trait_id).get("category", "")) == "origin":
            origin_count += 1
    assert(origin_count == 2)

    var previous_strength: int = gladiator.strength
    var previous_health: int = gladiator.health
    assert(TraitManager.award_trait(gladiator.id, "encouraging"))
    assert(gladiator.strength == previous_strength + 1)
    assert(gladiator.health == previous_health + 5)
    assert(not TraitManager.award_trait(gladiator.id, "encouraging"))
    assert(gladiator.strength == previous_strength + 1)
    assert(gladiator.health == previous_health + 5)

    var before_stats := [gladiator.strength, gladiator.agility, gladiator.endurance, gladiator.intelligence, gladiator.technique]
    assert(TraitManager.award_trait(gladiator.id, "dreamer"))
    assert(gladiator.strength == before_stats[0] + 1)
    assert(gladiator.agility == before_stats[1] + 1)
    assert(gladiator.endurance == before_stats[2] + 1)
    assert(gladiator.intelligence == before_stats[3] + 1)
    assert(gladiator.technique == before_stats[4] + 1)
    assert(not TraitManager.award_trait(gladiator.id, origin_ids[0]))

    print("Trait catalog and deterministic awards contract: OK")
    get_tree().quit()
