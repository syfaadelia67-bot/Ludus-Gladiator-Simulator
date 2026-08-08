extends Node

signal estate_changed
signal upgrade_completed(building_id: String, new_level: int)
signal upgrade_failed(reason: String)

const CATALOG_PATH := "res://data/buildings.json"
const REMOVED_LEGACY_IDS: Array[String] = [
	"kitchen",
	"warehouse",
	"worker_quarters",
	"wall_and_gate",
	"guard_post",
	"security",
	"sanctuary",
	"private_arena",
	"stable",
]

var BUILDINGS: Dictionary = {}
var LEGACY_ID_ALIASES: Dictionary = {}
var levels: Dictionary = {}
var demo_mode: bool = true


func _ready() -> void:
	_ensure_catalog_loaded()
	_ensure_level_entries()
	_apply_global_effects()


func _ensure_catalog_loaded() -> void:
	if not BUILDINGS.is_empty():
		return
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("No se encontró el catálogo de edificios: %s" % CATALOG_PATH)
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el catálogo de edificios: %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		push_error("El catálogo de edificios debe contener un Array JSON.")
		return
	for entry in parsed:
		if not entry is Dictionary:
			continue
		var building_id := str(entry.get("id", ""))
		if building_id.is_empty() or BUILDINGS.has(building_id):
			continue
		BUILDINGS[building_id] = entry.duplicate(true)
		for legacy_id in entry.get("legacy_ids", []):
			var legacy_key := str(legacy_id)
			if not legacy_key.is_empty():
				LEGACY_ID_ALIASES[legacy_key] = building_id


func _ensure_level_entries() -> void:
	_ensure_catalog_loaded()
	for building_id in BUILDINGS.keys():
		if levels.has(building_id):
			continue
		var data: Dictionary = BUILDINGS[building_id]
		levels[building_id] = int(data.get("starting_level", 0))


func canonicalize_building_id(building_id: String) -> String:
	_ensure_catalog_loaded()
	if BUILDINGS.has(building_id):
		return building_id
	if LEGACY_ID_ALIASES.has(building_id):
		return str(LEGACY_ID_ALIASES[building_id])
	if REMOVED_LEGACY_IDS.has(building_id):
		return ""
	return building_id


func migrate_levels(raw_levels: Dictionary) -> Dictionary:
	_ensure_catalog_loaded()
	var migrated: Dictionary = {}
	for raw_id in raw_levels.keys():
		var canonical_id := canonicalize_building_id(str(raw_id))
		if not BUILDINGS.has(canonical_id):
			continue
		var incoming_level := int(raw_levels[raw_id])
		migrated[canonical_id] = maxi(int(migrated.get(canonical_id, 0)), incoming_level)
	for building_id in BUILDINGS.keys():
		var data: Dictionary = BUILDINGS[building_id]
		var default_level := int(data.get("starting_level", 0))
		var max_level := int(data.get("max_level", 10))
		migrated[building_id] = clampi(
			int(migrated.get(building_id, default_level)), 0, max_level
		)
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
	estate_changed.emit()


func get_level(building_id: String) -> int:
	_ensure_level_entries()
	return int(levels.get(canonicalize_building_id(building_id), 0))


func is_demo_available(building_id: String) -> bool:
	_ensure_catalog_loaded()
	var canonical_id := canonicalize_building_id(building_id)
	return BUILDINGS.has(canonical_id) and bool(
		BUILDINGS[canonical_id].get("demo_available", false)
	)


func is_locked(building_id: String) -> bool:
	return demo_mode and not is_demo_available(building_id)


func get_effective_max_level(building_id: String) -> int:
	_ensure_catalog_loaded()
	var canonical_id := canonicalize_building_id(building_id)
	if not BUILDINGS.has(canonical_id):
		return 0
	var data: Dictionary = BUILDINGS[canonical_id]
	if demo_mode:
		return int(data.get("demo_max_level", 0))
	return int(data.get("max_level", 10))


func get_upgrade_cost(building_id: String) -> int:
	_ensure_catalog_loaded()
	var canonical_id := canonicalize_building_id(building_id)
	if not BUILDINGS.has(canonical_id):
		return 0
	var data: Dictionary = BUILDINGS[canonical_id]
	if bool(data.get("upgrade_cost_pending", false)):
		return 0
	var level := get_level(canonical_id)
	return int(float(data.get("base_cost", 0)) * pow(1.65, level))


func can_upgrade(building_id: String) -> bool:
	var canonical_id := canonicalize_building_id(building_id)
	if not BUILDINGS.has(canonical_id) or is_locked(canonical_id):
		return false
	if bool(BUILDINGS[canonical_id].get("upgrade_cost_pending", false)):
		return false
	return get_level(canonical_id) < get_effective_max_level(canonical_id)


func upgrade(building_id: String) -> bool:
	var canonical_id := canonicalize_building_id(building_id)
	if not BUILDINGS.has(canonical_id):
		upgrade_failed.emit("Instalación desconocida.")
		return false
	if is_locked(canonical_id):
		upgrade_failed.emit("Esta instalación no está disponible en la demo.")
		return false
	if bool(BUILDINGS[canonical_id].get("upgrade_cost_pending", false)):
		upgrade_failed.emit(
			"El coste de mejora de esta instalación aún no está migrado al balance mensual."
		)
		return false
	var level := get_level(canonical_id)
	if level >= get_effective_max_level(canonical_id):
		upgrade_failed.emit("La instalación ya alcanzó el nivel máximo disponible.")
		return false
	var cost := get_upgrade_cost(canonical_id)
	if not GameState.spend_denarii(cost):
		upgrade_failed.emit("No hay suficientes denarios para mejorar la instalación.")
		return false
	levels[canonical_id] = level + 1
	_apply_global_effects()
	upgrade_completed.emit(canonical_id, level + 1)
	estate_changed.emit()
	return true


func _apply_global_effects() -> void:
	_ensure_level_entries()
	RosterManager.capacity = 4 + get_level("barracks") * 4
	RosterManager.roster_changed.emit()


func get_training_multiplier() -> float:
	return 1.0 + float(get_level("training_yard")) * 0.20


func get_recovery_bonus() -> int:
	return get_level("infirmary") * 3


func get_security_bonus() -> int:
	return 0


func get_forge_level() -> int:
	return get_level("forge")


func get_building_ids() -> Array[String]:
	_ensure_catalog_loaded()
	var result: Array[String] = []
	for building_id in BUILDINGS.keys():
		result.append(str(building_id))
	result.sort()
	return result


func get_building_data(building_id: String) -> Dictionary:
	_ensure_catalog_loaded()
	var canonical_id := canonicalize_building_id(building_id)
	if not BUILDINGS.has(canonical_id):
		return {}
	var data: Dictionary = BUILDINGS[canonical_id].duplicate(true)
	data["id"] = canonical_id
	data["level"] = get_level(canonical_id)
	data["upgrade_cost"] = get_upgrade_cost(canonical_id)
	data["locked"] = is_locked(canonical_id)
	data["effective_max_level"] = get_effective_max_level(canonical_id)
	return data
