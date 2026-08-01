extends "res://scripts/systems/combat_history_manager.gd"

func _on_combat_finished(result: Dictionary) -> void:
    super._on_combat_finished(result)
    if entries.is_empty():
        return
    var current_week := GameState.get_week()
    entries[0]["week"] = current_week
    entries[0]["day"] = current_week
    history_changed.emit()

func import_state(data: Dictionary, current_day: int = -1) -> void:
    var migrated := data.duplicate(true)
    var migrated_entries: Array = []
    for raw_entry in data.get("entries", []):
        if not raw_entry is Dictionary:
            continue
        var entry: Dictionary = raw_entry.duplicate(true)
        var week := maxi(1, int(entry.get("week", entry.get("day", 1))))
        entry["week"] = week
        entry["day"] = week
        migrated_entries.append(entry)
    migrated["entries"] = migrated_entries
    super.import_state(migrated, current_day if current_day >= 1 else GameState.get_week())

func get_entries() -> Array[Dictionary]:
    var result := super.get_entries()
    for entry in result:
        if entry is Dictionary:
            entry["week"] = maxi(1, int(entry.get("week", entry.get("day", 1))))
    return result
