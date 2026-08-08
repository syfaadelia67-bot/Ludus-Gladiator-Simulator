extends Node

signal owner_configured(profile: Dictionary)
signal tutorial_state_changed(completed: bool)
signal tutorial_progress_changed(progress: Dictionary)

const ORIGINS_PATH := "res://data/dominus_origins.json"
const LEGACY_PROFILE_PATH := "user://ludus_owner_profile.json"
const VALID_TITLES := ["dominus", "domina"]
const TUTORIAL_STEP_COUNT := 5
const TUTORIAL_OBJECTIVE_IDS := [
	"inspect_roster", "advance_week", "obtain_equipment", "resolve_event", "weekly_combat"
]

var profile: Dictionary = _default_profile()
var origins: Dictionary = {}


func _ready() -> void:
	_load_origins()
	_import_legacy_profile_once()


func _default_profile() -> Dictionary:
	return {
		"configured": false,
		"title": "dominus",
		"display_name": "",
		"origin_id": "",
		"tutorial_completed": false,
		"tutorial_progress": {"current_step": 0, "completed_objectives": {}},
		"bonuses_applied": false
	}


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
	_reset_campaign_for_new_owner()
	profile = _default_profile()
	profile["configured"] = true
	profile["title"] = canonical_title
	profile["display_name"] = (
		display_name.strip_edges()
		if not display_name.strip_edges().is_empty()
		else canonical_title.capitalize()
	)
	profile["origin_id"] = origin_id
	_apply_origin_bonuses_once()
	owner_configured.emit(get_profile())
	return true


func _reset_campaign_for_new_owner() -> void:
	var starting_resources := DataRepository.get_economy_rule("demo_starting_resources")
	GameState.day = 1
	GameState.denarii = int(starting_resources.get("denarii", 0))
	GameState.food = 100
	GameState.ore = 20
	GameState.reputation = 0

	RosterManager.people.clear()
	RosterManager.capacity = 8
	RosterManager.security_score = 0
	RosterManager.intelligence_points = 0
	RosterManager._seed_initial_roster()

	EstateManager.import_levels({})
	EquipmentManager.inventory.clear()
	EquipmentManager.serial = 0
	MarketManager.offers.clear()
	MarketManager._serial = 0
	MarketManager.refresh_market(false)

	RivalManager.rivals.clear()
	RivalManager.hostility_heat = 0
	RivalManager.operations_completed = 0
	RivalManager.operations_detected = 0
	RivalManager._seed_rivals()

	CombatManager.last_combat_day = -1
	CombatManager.last_result = {}
	CombatManager.next_battle_config = {}
	CombatHistoryManager.import_state({})
	EventManager.import_state({})
	EconomyManager.import_state({})
	TournamentManager.import_state({})
	CampaignManager.import_state({})
	PersonalityManager.import_state({})
	RelationshipManager.import_state({})
	GladiatorProgressionManager.import_state({})
	TraitManager.import_state({})
	TransferManager.import_state({})

	GameState.resources_changed.emit()
	RosterManager.roster_changed.emit()
	EquipmentManager.inventory_changed.emit()
	MarketManager.market_changed.emit()
	RivalManager.rivals_changed.emit()
	EventManager.events_changed.emit()
	EconomyManager.economy_changed.emit()
	TournamentManager.calendar_changed.emit()
	CampaignManager.campaign_changed.emit()
	PersonalityManager.personality_changed.emit("")
	RelationshipManager.relationships_changed.emit()
	GladiatorProgressionManager.progression_changed.emit()
	TransferManager.transfers_changed.emit()


func reset_profile() -> void:
	profile = _default_profile()
	_remove_legacy_profile()


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


func update_tutorial_progress(current_step: int, completed_objectives: Dictionary) -> void:
	if bool(profile.get("tutorial_completed", false)):
		return
	var sanitized_objectives := _sanitize_tutorial_objectives(completed_objectives)
	var progress := {
		"current_step": clampi(current_step, 0, TUTORIAL_STEP_COUNT - 1),
		"completed_objectives": sanitized_objectives
	}
	if profile.get("tutorial_progress", {}) == progress:
		return
	profile["tutorial_progress"] = progress
	tutorial_progress_changed.emit(get_tutorial_progress())
	if SaveManager.has_save():
		SaveManager.call_deferred("save_game")


func get_tutorial_progress() -> Dictionary:
	var progress: Variant = profile.get("tutorial_progress", {})
	return (
		progress.duplicate(true)
		if progress is Dictionary
		else {"current_step": 0, "completed_objectives": {}}
	)


func mark_tutorial_completed() -> void:
	if bool(profile.get("tutorial_completed", false)):
		return
	profile["tutorial_completed"] = true
	profile["tutorial_progress"] = {
		"current_step": TUTORIAL_STEP_COUNT - 1,
		"completed_objectives":
		_sanitize_tutorial_objectives(get_tutorial_progress().get("completed_objectives", {}))
	}
	tutorial_state_changed.emit(true)
	if SaveManager.has_save():
		SaveManager.call_deferred("save_game")


func should_show_onboarding() -> bool:
	return not bool(profile.get("configured", false))


func should_show_tutorial() -> bool:
	return (
		bool(profile.get("configured", false))
		and not bool(profile.get("tutorial_completed", false))
	)


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
	_sanitize_profile()
	_remove_legacy_profile()


func _sanitize_profile() -> void:
	profile["configured"] = bool(profile.get("configured", false))
	profile["title"] = str(profile.get("title", "dominus"))
	if not VALID_TITLES.has(profile["title"]):
		profile["title"] = "dominus"
	profile["display_name"] = str(profile.get("display_name", ""))
	profile["origin_id"] = str(profile.get("origin_id", ""))
	if not profile["origin_id"].is_empty() and not origins.has(profile["origin_id"]):
		profile["origin_id"] = ""
		profile["configured"] = false
	profile["tutorial_completed"] = bool(profile.get("tutorial_completed", false))
	var raw_progress: Variant = profile.get("tutorial_progress", {})
	var raw_objectives: Variant = (
		raw_progress.get("completed_objectives", {}) if raw_progress is Dictionary else {}
	)
	profile["tutorial_progress"] = {
		"current_step":
		clampi(
			int(raw_progress.get("current_step", 0)) if raw_progress is Dictionary else 0,
			0,
			TUTORIAL_STEP_COUNT - 1
		),
		"completed_objectives": _sanitize_tutorial_objectives(raw_objectives)
	}
	profile["bonuses_applied"] = bool(profile.get("bonuses_applied", false))


func _sanitize_tutorial_objectives(raw_objectives: Variant) -> Dictionary:
	var sanitized: Dictionary = {}
	if not raw_objectives is Dictionary:
		return sanitized
	for objective_id in TUTORIAL_OBJECTIVE_IDS:
		if bool(raw_objectives.get(objective_id, false)):
			sanitized[objective_id] = true
	return sanitized


func _import_legacy_profile_once() -> void:
	if not FileAccess.file_exists(LEGACY_PROFILE_PATH):
		return
	var file := FileAccess.open(LEGACY_PROFILE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var loaded: Variant = parsed.get("profile", {})
		if loaded is Dictionary:
			profile = loaded.duplicate(true)
			_sanitize_profile()
	_remove_legacy_profile()


func _remove_legacy_profile() -> void:
	if FileAccess.file_exists(LEGACY_PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_PROFILE_PATH))
