extends Node

signal estate_changed
signal upgrade_completed(building_id: String, new_level: int)
signal upgrade_failed(reason: String)

const BUILDINGS := {
    "barracks": {"name":"Barracones","base_cost":220,"max_level":5,"description":"Aumenta la capacidad del ludus."},
    "training_yard": {"name":"Patio de entrenamiento","base_cost":260,"max_level":5,"description":"Aumenta la experiencia ganada al entrenar."},
    "forge": {"name":"Forja","base_cost":320,"max_level":5,"description":"Desbloquea equipo de mayor calidad."},
    "infirmary": {"name":"Enfermería","base_cost":280,"max_level":5,"description":"Mejora la recuperación diaria."},
    "guard_post": {"name":"Puesto de guardia","base_cost":240,"max_level":5,"description":"Aporta seguridad permanente."}
}

var levels := {
    "barracks": 1,
    "training_yard": 1,
    "forge": 1,
    "infirmary": 1,
    "guard_post": 1
}

func get_level(building_id: String) -> int:
    return int(levels.get(building_id, 0))

func get_upgrade_cost(building_id: String) -> int:
    if not BUILDINGS.has(building_id):
        return 0
    var level := get_level(building_id)
    return int(BUILDINGS[building_id].base_cost * pow(1.65, level - 1))

func upgrade(building_id: String) -> bool:
    if not BUILDINGS.has(building_id):
        upgrade_failed.emit("Instalación desconocida.")
        return false
    var level := get_level(building_id)
    if level >= int(BUILDINGS[building_id].max_level):
        upgrade_failed.emit("La instalación ya alcanzó su nivel máximo.")
        return false
    var cost := get_upgrade_cost(building_id)
    if not GameState.spend_denarii(cost):
        upgrade_failed.emit("No hay suficientes denarios para mejorar la instalación.")
        return false
    levels[building_id] = level + 1
    _apply_global_effects()
    upgrade_completed.emit(building_id, level + 1)
    estate_changed.emit()
    return true

func _apply_global_effects() -> void:
    RosterManager.capacity = 4 + get_level("barracks") * 4
    RosterManager.roster_changed.emit()

func get_training_multiplier() -> float:
    return 1.0 + float(get_level("training_yard") - 1) * 0.20

func get_recovery_bonus() -> int:
    return (get_level("infirmary") - 1) * 3

func get_security_bonus() -> int:
    return get_level("guard_post") * 3

func get_forge_level() -> int:
    return get_level("forge")

func get_building_ids() -> Array[String]:
    var result: Array[String] = []
    for building_id in BUILDINGS.keys():
        result.append(str(building_id))
    return result

func get_building_data(building_id: String) -> Dictionary:
    var data: Dictionary = BUILDINGS.get(building_id, {}).duplicate(true)
    data["id"] = building_id
    data["level"] = get_level(building_id)
    data["upgrade_cost"] = get_upgrade_cost(building_id)
    return data
