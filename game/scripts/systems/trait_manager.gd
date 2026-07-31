extends Node

signal trait_awarded(person_id: String, trait_id: String)
signal traits_changed(person_id: String)

const ORIGIN_TRAITS_PER_GLADIATOR := 2

var catalog: Dictionary = {}
var achievement_state: Dictionary = {}

func _ready() -> void:
    _load_catalog()
    RosterManager.roster_changed.connect(_ensure_roster_traits)
    CombatManager.combat_finished.connect(_on_combat_finished)
    call_deferred("_ensure_roster_traits")

func _load_catalog() -> void:
    catalog.clear()
    for entry in DataRepository.traits:
        if entry is Dictionary:
            catalog[str(entry.get("id", ""))] = entry.duplicate(true)

func get_trait(trait_id: String) -> Dictionary:
    return catalog.get(trait_id, {}).duplicate(true)

func get_origin_trait_ids() -> Array[String]:
    return _ids_for_category("origin")

func get_obtainable_trait_ids() -> Array[String]:
    return _ids_for_category("obtainable")

func get_trait_name(trait_id: String) -> String:
    return str(catalog.get(trait_id, {}).get("name", trait_id.capitalize()))

func ensure_gladiator_origin_traits(person) -> void:
    if person == null or person.role != "gladiator":
        return
    var origin_ids: Array[String] = get_origin_trait_ids()
    var current_origin: Array[String] = []
    for trait_id in person.traits:
        if str(catalog.get(trait_id, {}).get("category", "")) == "origin":
            current_origin.append(trait_id)
    var cursor: int = absi(hash(person.id)) % maxi(1, origin_ids.size())
    while current_origin.size() < ORIGIN_TRAITS_PER_GLADIATOR and not origin_ids.is_empty():
        var candidate: String = origin_ids[cursor % origin_ids.size()]
        cursor += 1
        if person.traits.has(candidate):
            continue
        person.traits.append(candidate)
        current_origin.append(candidate)
    traits_changed.emit(person.id)

func award_trait(person_id: String, trait_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null or not catalog.has(trait_id) or person.traits.has(trait_id):
        return false
    if str(catalog[trait_id].get("category", "")) != "obtainable":
        return false
    person.traits.append(trait_id)
    _apply_permanent_effects(person, trait_id)
    trait_awarded.emit(person_id, trait_id)
    traits_changed.emit(person_id)
    RosterManager.roster_changed.emit()
    return true

func has_trait(person_id: String, trait_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    return person != null and person.traits.has(trait_id)

func get_combined_modifiers(person_id: String) -> Dictionary:
    var person = RosterManager.get_person(person_id)
    var combined: Dictionary = {}
    if person == null:
        return combined
    for trait_id in person.traits:
        var modifiers: Dictionary = catalog.get(trait_id, {}).get("modifiers", {})
        for key in modifiers.keys():
            var value = modifiers[key]
            if value is int or value is float:
                combined[key] = float(combined.get(key, 0.0)) + float(value)
            else:
                combined[key] = value
    return combined

func register_decision_trait(person_id: String, decision_id: String) -> bool:
    for trait_id in get_obtainable_trait_ids():
        var trigger: Dictionary = catalog.get(trait_id, {}).get("trigger", {})
        if str(trigger.get("type", "")) == "decision" and str(trigger.get("value", "")) == decision_id:
            return award_trait(person_id, trait_id)
    return false

func export_state() -> Dictionary:
    return {"achievement_state":achievement_state.duplicate(true)}

func import_state(data: Dictionary) -> void:
    achievement_state = data.get("achievement_state", {}).duplicate(true)
    _ensure_roster_traits()

func _ensure_roster_traits() -> void:
    for person in RosterManager.get_people():
        if person.role == "gladiator":
            ensure_gladiator_origin_traits(person)

func _on_combat_finished(result: Dictionary) -> void:
    var person_id := str(result.get("fighter_id", ""))
    if person_id.is_empty():
        return
    var state: Dictionary = achievement_state.get(person_id, {"consecutive_wins":0,"fights":0,"critical_survivals":0})
    state["fights"] = int(state.get("fights", 0)) + 1
    if bool(result.get("victory", false)):
        state["consecutive_wins"] = int(state.get("consecutive_wins", 0)) + 1
    else:
        state["consecutive_wins"] = 0
    var max_health := maxi(1, int(result.get("player_max_health", 1)))
    var remaining_health := maxi(0, int(result.get("player_health", 0)))
    if bool(result.get("victory", false)) and float(remaining_health) / float(max_health) <= 0.15:
        state["critical_survivals"] = int(state.get("critical_survivals", 0)) + 1
        award_trait(person_id, "survivor")
    achievement_state[person_id] = state
    if int(state.get("consecutive_wins", 0)) >= 5:
        award_trait(person_id, "encouraging")
    if int(state.get("consecutive_wins", 0)) >= 8:
        award_trait(person_id, "undefeated")
    if int(state.get("fights", 0)) >= 12:
        award_trait(person_id, "battle_hardened")

func _apply_permanent_effects(person, trait_id: String) -> void:
    if person.applied_trait_effects.has(trait_id):
        return
    var effects: Dictionary = catalog.get(trait_id, {}).get("permanent_effects", {})
    if effects.is_empty():
        return
    person.apply_growth(effects)
    person.applied_trait_effects.append(trait_id)

func _ids_for_category(category: String) -> Array[String]:
    var result: Array[String] = []
    for trait_id in catalog.keys():
        if str(catalog[trait_id].get("category", "")) == category:
            result.append(str(trait_id))
    result.sort()
    return result
