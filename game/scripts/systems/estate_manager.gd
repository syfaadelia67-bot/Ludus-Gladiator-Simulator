extends Node

signal estate_changed
signal upgrade_completed(building_id: String, new_level: int)
signal upgrade_failed(reason: String)

const DEMO_ESTATE_RUNTIME_POLICY = preload("res://scripts/systems/demo_estate_runtime_policy.gd")
const LEGACY_UPGRADE_COST_GROWTH := 1.65
const BASE_ROSTER_CAPACITY := 4

var buildings: Dictionary = {}
var legacy_id_aliases: Dictionary = {}
var levels: Dictionary = {}
var demo_mode: bool = true


func _ready() -> void:
	_ensure_catalog_loaded()
	_ensure_level_entries()
	_apply_global_effects()


func _ensure_catalog_loaded() -> void:
	if not buildings.is_empty():
		return
	for entry in DataRepository.get_buildings():
		if not entry is Dictionary:
			continue
		var building_id := str(entry.get("id", ""))
		if building_id.is_empty() or buildings.has(building_id):
			continue
		buildings[building_id] = entry.duplicate(true)
		for legacy_id in entry.get("legacy_ids", []):
			var legacy_key := str(legacy_id)
			if not legacy_key.is_empty():
				legacy_id_aliases[legacy_key] = building_id


func _ensure_level_entries() -> void:
	_ensure_catalog_loaded()
	for building_id in buildings.keys():
		if levels.has(building_id):
			continue
		var data: Dictionary = buildings[building_id]
		levels[building_id] = int(data.get("starting_level", 0))


func canonicalize_building_id(building_id: String) -> String:
	_ensure_catalog_loaded()
	if buildings.has(building_id):
		return building_id
	if legacy_id_aliases.has(building_id):
		return str(legacy_id_aliases[building_id])
	return building_id


func migrate_levels(raw_levels: Dictionary) -> Dictionary:
	_ensure_catalog_loaded()
	var migrated: Dictionary = {}
	for raw_id in raw_levels.keys():
		var canonical_id := canonicalize_building_id(str(raw_id))
		if not buildings.has(canonical_id):
			continue
		var incoming_level := int(raw_levels[raw_id])
		migrated[canonical_id] = maxi(int(migrated.get(canonical_id, 0)), incoming_level)
	for building_id in buildings.keys():
		var data: Dictionary = buildings[building_id]
		var default_level := int(data.get("starting_level", 0))
		var max_level := int(data.get("max_level", 10))
		migrated[building_id] = clampi(int(migrated.get(building_id, default_level)), 0, max_level)
	return migrated


func import_levels(raw_levels: Dictionary) -> void:
	levels = migrate_levels(raw_levels)
	_apply_global_effects()
	estate_changed.emit()


func export_levels() -> Dictionary:
	_ensure_level_entries()
	return levels.duplicate(true)


func set_demo_mode(enabled: bool) -> void:
	demo_mode = enabled
	_apply_global_effects()
	estate_changed.emit()


func get_level(building_id: String) -> int:
	_ensure_level_entries()
	return int(levels.get(canonicalize_building_id(building_id), 0))


func is_constructed(building_id: String) -> bool:
	return get_level(building_id) > 0


func is_demo_available(building_id: String) -> bool:
	_ensure_catalog_loaded()
	var canonical_id := canonicalize_building_id(building_id)
	return (
		buildings.has(canonical_id) and bool(buildings[canonical_id].get("demo_available", false))
	)


func is_locked(building_id: String) -> bool:
	return demo_mode and not is_demo_available(building_id)


func get_effective_max_level(building_id: String) -> int:
	_ensure_catalog_loaded()
	var canonical_id := canonicalize_building_id(building_id)
	if not buildings.has(canonical_id):
		return 0
	var data: Dictionary = buildings[canonical_id]
	if demo_mode:
		return int(data.get("demo_max_level", 0))
	return int(data.get("max_level", 10))


func get_upgrade_cost(building_id: String) -> int:
	_ensure_catalog_loaded()
	var canonical_id := canonicalize_building_id(building_id)
	if not buildings.has(canonical_id):
		return 0
	var data: Dictionary = buildings[canonical_id]
	if bool(data.get("upgrade_cost_pending", false)):
		return 0
	var level := get_level(canonical_id)
	return int(float(data.get("base_cost", 0)) * pow(LEGACY_UPGRADE_COST_GROWTH, level))


func get_upgrade_status(building_id: String) -> Dictionary:
	var canonical_id := canonicalize_building_id(building_id)
	if not buildings.has(canonical_id):
		return {
			"can_upgrade": false,
			"code": "unknown_building",
			"reason": "Instalación desconocida.",
			"cost": 0,
		}
	if is_locked(canonical_id):
		return {
			"can_upgrade": false,
			"code": "full_game_only",
			"reason": "Esta instalación no está disponible en la demo.",
			"cost": 0,
		}
	if CampaignManager.campaign_over:
		return {
			"can_upgrade": false,
			"code": "campaign_over",
			"reason": "La campaña terminó. La Finca está disponible solo para consulta.",
			"cost": 0,
		}
	if bool(buildings[canonical_id].get("upgrade_cost_pending", false)):
		return {
			"can_upgrade": false,
			"code": "upgrade_cost_pending",
			"reason": "El coste de mejora todavía está pendiente de balance canónico.",
			"cost": 0,
		}
	var level := get_level(canonical_id)
	var max_level := get_effective_max_level(canonical_id)
	if level >= max_level:
		return {
			"can_upgrade": false,
			"code": "max_level",
			"reason": "La instalación ya alcanzó el nivel máximo disponible.",
			"cost": 0,
		}
	return {
		"can_upgrade": true,
		"code": "available",
		"reason": "",
		"cost": get_upgrade_cost(canonical_id),
		"current_level": level,
		"next_level": level + 1,
		"max_level": max_level,
	}


func can_upgrade(building_id: String) -> bool:
	return bool(get_upgrade_status(building_id).get("can_upgrade", false))


func upgrade(building_id: String) -> bool:
	var canonical_id := canonicalize_building_id(building_id)
	var status := get_upgrade_status(canonical_id)
	if not bool(status.get("can_upgrade", false)):
		upgrade_failed.emit(str(status.get("reason", "No se puede mejorar esta instalación.")))
		return false
	var cost := int(status.get("cost", 0))
	if not GameState.spend_denarii(cost):
		upgrade_failed.emit("No hay suficientes denarios para mejorar la instalación.")
		return false
	var new_level := get_level(canonical_id) + 1
	levels[canonical_id] = new_level
	_apply_global_effects()
	upgrade_completed.emit(canonical_id, new_level)
	estate_changed.emit()
	return true


func _apply_global_effects() -> void:
	_ensure_level_entries()
	var barracks: Dictionary = buildings.get("barracks", {})
	var per_level := int(barracks.get("effect_per_level", 4))
	RosterManager.capacity = BASE_ROSTER_CAPACITY + get_level("barracks") * per_level
	RosterManager.roster_changed.emit()


func get_training_multiplier() -> float:
	if demo_mode and not DEMO_ESTATE_RUNTIME_POLICY.can_apply_training_numeric_effect():
		return 1.0
	return 1.0 + float(get_level("training_yard")) * 0.20


func get_recovery_bonus() -> int:
	if demo_mode and not DEMO_ESTATE_RUNTIME_POLICY.can_apply_recovery_numeric_effect():
		return 0
	return get_level("infirmary") * 3


func get_security_bonus() -> int:
	if demo_mode:
		return 0
	return get_level("wall_and_gate") * 3


func get_forge_level() -> int:
	return get_level("forge")


func get_building_effect_status(building_id: String) -> Dictionary:
	var canonical_id := canonicalize_building_id(building_id)
	if demo_mode:
		return DEMO_ESTATE_RUNTIME_POLICY.get_effect_status(canonical_id)
	return {
		"status": "legacy_full_game_runtime",
		"structural_effect_active": true,
		"numeric_balance_ready": true,
	}


func get_building_ids() -> Array[String]:
	_ensure_catalog_loaded()
	var result: Array[String] = []
	for building_id in buildings.keys():
		result.append(str(building_id))
	result.sort()
	return result


func get_demo_building_ids() -> Array[String]:
	_ensure_catalog_loaded()
	var result: Array[String] = []
	for building_id in buildings.keys():
		if bool(buildings[building_id].get("demo_available", false)):
			result.append(str(building_id))
	result.sort()
	return result


func get_building_data(building_id: String) -> Dictionary:
	_ensure_catalog_loaded()
	var canonical_id := canonicalize_building_id(building_id)
	if not buildings.has(canonical_id):
		return {}
	var data: Dictionary = buildings[canonical_id].duplicate(true)
	var upgrade_status := get_upgrade_status(canonical_id)
	data["id"] = canonical_id
	data["level"] = get_level(canonical_id)
	data["constructed"] = is_constructed(canonical_id)
	data["upgrade_cost"] = int(upgrade_status.get("cost", 0))
	data["upgrade_status"] = upgrade_status
	data["locked"] = is_locked(canonical_id)
	data["effective_max_level"] = get_effective_max_level(canonical_id)
	data["effect_status"] = get_building_effect_status(canonical_id)
	return data
