class_name MarketValuation
extends RefCounted

const ATTRIBUTE_VALUE := 12
const HEALTH_POINT_VALUE := 2
const ORIGIN_TRAIT_VALUE := 35
const OBTAINABLE_TRAIT_VALUE := 60
const GLADIATOR_ROLE_VALUE := 180
const LEVEL_VALUE := 45
const FAME_VALUE := 4
const WIN_VALUE := 18

static func value_offer(offer: Dictionary) -> int:
    var attributes: int = int(offer.get("strength", 5)) + int(offer.get("agility", 5)) + int(offer.get("endurance", 5)) + int(offer.get("intelligence", 5)) + int(offer.get("technique", 5))
    var value: int = 90 + attributes * ATTRIBUTE_VALUE
    value += maxi(1, int(offer.get("health", 50))) * HEALTH_POINT_VALUE
    value += _trait_value(offer.get("traits", []))
    if str(offer.get("role", "slave")) == "gladiator":
        value += GLADIATOR_ROLE_VALUE
    return maxi(50, value)

static func value_person(person, progression: Dictionary = {}) -> int:
    if person == null:
        return 0
    var attributes: int = int(person.strength) + int(person.agility) + int(person.endurance) + int(person.intelligence) + int(person.technique)
    var value: int = attributes * ATTRIBUTE_VALUE + maxi(1, int(person.health)) * HEALTH_POINT_VALUE
    value += _trait_value(person.traits)
    value += int(progression.get("level", 1)) * LEVEL_VALUE
    value += int(progression.get("fame", 0)) * FAME_VALUE
    value += int(progression.get("wins", 0)) * WIN_VALUE
    if int(person.injury_days) > 0:
        value = int(round(value * 0.75))
    if str(progression.get("career_state", "activo")) == "declive":
        value = int(round(value * 0.80))
    return maxi(50, value)

# Compatibility aliases for any code written against the earlier names.
static func offer_value(offer: Dictionary) -> int:
    return value_offer(offer)

static func person_value(person, progression: Dictionary = {}) -> int:
    return value_person(person, progression)

static func _trait_value(traits: Array) -> int:
    var total: int = 0
    for trait_id in traits:
        var data: Dictionary = TraitManager.get_trait(str(trait_id))
        if str(data.get("category", "origin")) == "obtainable":
            total += OBTAINABLE_TRAIT_VALUE
        else:
            total += ORIGIN_TRAIT_VALUE
    return total
