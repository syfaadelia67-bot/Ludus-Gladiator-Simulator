extends RefCounted
class_name HistoryIntegrityValidator

static func validate(entries: Array[Dictionary], current_day: int) -> Dictionary:
    var invalid_entries: int = 0
    var future_entries: int = 0
    var duplicate_entries: int = 0
    var signatures: Dictionary = {}

    for entry: Dictionary in entries:
        if not _is_valid_entry(entry):
            invalid_entries += 1
        if int(entry.get("day", 0)) > current_day:
            future_entries += 1

        var signature: String = "%d|%s|%s|%s" % [
            int(entry.get("day", 0)),
            str(entry.get("fighter_id", "")),
            str(entry.get("enemy", "")),
            str(entry.get("event_type", ""))
        ]
        if signatures.has(signature):
            duplicate_entries += 1
        signatures[signature] = true

    return {
        "valid": invalid_entries == 0 and future_entries == 0,
        "entries": entries.size(),
        "invalid_entries": invalid_entries,
        "future_entries": future_entries,
        "duplicate_entries": duplicate_entries
    }

static func sanitize(raw_entries: Array, maximum_entries: int = 60) -> Array[Dictionary]:
    var sanitized: Array[Dictionary] = []
    for raw_entry: Variant in raw_entries:
        if not raw_entry is Dictionary:
            continue
        var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
        if not _is_valid_entry(entry):
            continue
        sanitized.append(entry)
        if sanitized.size() >= maximum_entries:
            break
    return sanitized

static func _is_valid_entry(entry: Dictionary) -> bool:
    if int(entry.get("day", 0)) <= 0:
        return false
    if str(entry.get("fighter", "")).is_empty():
        return false
    if str(entry.get("enemy", "")).is_empty():
        return false
    if int(entry.get("rounds", 0)) < 0:
        return false
    return true
