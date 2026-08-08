extends Node

signal trait_awarded(person_id: String, trait_id: String)
signal traits_changed(person_id: String)

const MAX_NORMAL_TRAITS := 3

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
            var trait_id := str(entry.get("id", ""))
            if not trait_id.is_empty():
                catalog[trait_id] = entry.duplicate(true)

func get_trait(trait_id: String) -> Dictionary:
    return catalog.get(trait_id, {}).duplicate(true)

func get_normal_trait_ids() -> Array[String]:
    return _ids_for_category("normal")

func get_origin_trait_ids() -> Array[String]:
    return []

func get_obtainable_trait_ids() -> Array[String]:
    return []

func get_trait_name(trait_id: String) -> String:
    return str(catalog.get(trait_id, {}).get("name", trait_id.capitalize()))

func ensure_gladiator_origin_traits(person) -> void:
    if person == null or person.role != "gladiator":
        return
    # Legacy API retained for Save v14/caller compatibility. The frozen design no longer
    # auto-assigns a separate origin-trait category.

func award_trait(person_id: String, trait_id: String) -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null or not catalog.has(trait_id) or person.traits.has(trait_id):
        return false
    var trait_data: Dictionary = catalog[trait_id]
    if str(trait_data.get("category", "")) != "normal":
        return false
    if _normal_trait_count(person) >= MAX_NORMAL_TRAITS:
        return false
    if _has_incompatible_trait(person, trait_id):
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

func register_decision_trait(_person_id: String, _decision_id: String) -> bool:
    return false

func export_state() -> Dictionary:
    return {"achievement_state": achievement_state.duplicate(true)}

func import_state(data: Dictionary) -> void:
    achievement_state = data.get("achievement_state", {}).duplicate(true)
    _ensure_roster_traits()

func _ensure_roster_traits() -> void:
    # Intentionally does not rewrite legacy Save v14 trait ids during load.
    # Unknown historical traits remain inert until a dedicated save migration is justified.
    pass

func _on_combat_finished(result: Dictionary) -> void:
    var person_id := str(result.get("fighter_id", ""))
    if person_id.is_empty():
        return
    var state: Dictionary = achievement_state.get(
        person_id,
        {"consecutive_wins": 0, "fights": 0, "critical_survivals": 0}
    )
    state["fights"] = int(state.get("fights", 0)) + 1
    if bool(result.get("victory", false)):
        state["consecutive_wins"] = int(state.get("consecutive_wins", 0)) + 1
    else:
        state["consecutive_wins"] = 0
    var max_health := maxi(1, int(result.get("player_max_health", 1)))
    var remaining_health := maxi(0, int(result.get("player_health", 0)))
    if bool(result.get("victory", false)) and float(remaining_health) / float(max_health) <= 0.15:
        state["critical_survivals"] = int(state.get("critical_survivals", 0)) + 1
    achievement_state[person_id] = state

func _apply_permanent_effects(person, trait_id: String) -> void:
    if person.applied_trait_effects.has(trait_id):
        return
    var effects: Dictionary = catalog.get(trait_id, {}).get("permanent_effects", {})
    if effects.is_empty():
        return
    person.apply_growth(effects)
    person.applied_trait_effects.append(trait_id)

func _normal_trait_count(person) -> int:
    var count := 0
    for trait_id in person.traits:
        if str(catalog.get(trait_id, {}).get("category", "")) == "normal":
            count += 1
    return count

func _has_incompatible_trait(person, candidate_id: String) -> bool:
    var candidate: Dictionary = catalog.get(candidate_id, {})
    var candidate_incompatibilities: Array = candidate.get("incompatible_with", [])
    for existing_id in person.traits:
        if candidate_incompatibilities.has(str(existing_id)):
            return true
        var existing: Dictionary = catalog.get(existing_id, {})
        var existing_incompatibilities: Array = existing.get("incompatible_with", [])
        if existing_incompatibilities.has(candidate_id):
            return true
    return false

func _ids_for_category(category: String) -> Array[String]:
    var result: Array[String] = []
    for trait_id in catalog.keys():
        if str(catalog[trait_id].get("category", "")) == category:
            result.append(str(trait_id))
    result.sort()
    return result
