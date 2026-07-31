extends Node

signal owner_configured(profile: Dictionary)
signal tutorial_state_changed(completed: bool)

const ORIGINS_PATH := "res://data/dominus_origins.json"
const VALID_TITLES := ["dominus", "domina"]

var profile: Dictionary = {
    "configured": false,
    "title": "dominus",
    "display_name": "",
    "origin_id": "",
    "tutorial_completed": false,
    "bonuses_applied": false
}
var origins: Dictionary = {}

func _ready() -> void:
    _load_origins()

func _load_origins() -> void:
    origins.clear()
    if not FileAccess.file_exists(ORIGINS_PATH):
        push_error("No se encontró el catálogo de orígenes del Dominus o Domina.")
        return
    var file := FileAccess.open(ORIGINS_PATH, FileAccess.READ)
    if file == null:
        push_error("No se pudo abrir el catálogo de orígenes.")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Array:
        push_error("El catálogo de orígenes no tiene un formato válido.")
        return
    for raw_entry in parsed:
        if raw_entry is Dictionary:
            var entry: Dictionary = raw_entry
            var origin_id := str(entry.get("id", ""))
            if not origin_id.is_empty():
                origins[origin_id] = entry.duplicate(true)

func configure_owner(title: String, display_name: String, origin_id: String) -> bool:
    var canonical_title := title.to_lower()
    if not VALID_TITLES.has(canonical_title) or not origins.has(origin_id):
        return false
    profile["configured"] = true
    profile["title"] = canonical_title
    profile["display_name"] = display_name.strip_edges() if not display_name.strip_edges().is_empty() else canonical_title.capitalize()
    profile["origin_id"] = origin_id
    _apply_origin_bonuses_once()
    owner_configured.emit(get_profile())
    return true

func _apply_origin_bonuses_once() -> void:
    if bool(profile.get("bonuses_applied", false)):
        return
    var origin: Dictionary = get_origin(str(profile.get("origin_id", "")))
    var bonuses: Dictionary = origin.get("bonuses", {})
    GameState.denarii += int(bonuses.get("starting_denarii", 0))
    GameState.food += int(bonuses.get("starting_food", 0))
    GameState.ore += int(bonuses.get("starting_ore", 0))
    GameState.reputation += int(bonuses.get("starting_reputation", 0))
    var loyalty_bonus := int(bonuses.get("starting_loyalty", 0))
    var morale_bonus := int(bonuses.get("starting_morale", 0))
    for person in RosterManager.get_people():
        person.loyalty = clampi(person.loyalty + loyalty_bonus, 0, 100)
        person.morale = clampi(person.morale + morale_bonus, 0, 100)
    profile["bonuses_applied"] = true
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()

func get_gladiator_experience_multiplier() -> float:
    var origin: Dictionary = get_origin(str(profile.get("origin_id", "")))
    return maxf(1.0, float(origin.get("bonuses", {}).get("gladiator_experience_multiplier", 1.0)))

func mark_tutorial_completed() -> void:
    if bool(profile.get("tutorial_completed", false)):
        return
    profile["tutorial_completed"] = true
    tutorial_state_changed.emit(true)

func should_show_onboarding() -> bool:
    return not bool(profile.get("configured", false))

func should_show_tutorial() -> bool:
    return bool(profile.get("configured", false)) and not bool(profile.get("tutorial_completed", false))

func get_profile() -> Dictionary:
    return profile.duplicate(true)

func get_origin(origin_id: String) -> Dictionary:
    return origins.get(origin_id, {}).duplicate(true)

func get_origin_ids() -> Array[String]:
    var ids: Array[String] = []
    for origin_id in origins.keys():
        ids.append(str(origin_id))
    ids.sort()
    return ids

func get_title_label() -> String:
    return "Domina" if str(profile.get("title", "dominus")) == "domina" else "Dominus"

func export_state() -> Dictionary:
    return {"profile": profile.duplicate(true)}

func import_state(data: Dictionary) -> void:
    var loaded: Variant = data.get("profile", {})
    if loaded is Dictionary:
        profile = loaded.duplicate(true)
    profile["configured"] = bool(profile.get("configured", false))
    profile["title"] = str(profile.get("title", "dominus"))
    profile["display_name"] = str(profile.get("display_name", ""))
    profile["origin_id"] = str(profile.get("origin_id", ""))
    profile["tutorial_completed"] = bool(profile.get("tutorial_completed", false))
    profile["bonuses_applied"] = bool(profile.get("bonuses_applied", false))
