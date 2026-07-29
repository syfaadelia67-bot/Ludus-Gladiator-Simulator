extends SceneTree

func _init() -> void:
    var valid_entry: Dictionary = {
        "day": 3,
        "fighter": "Marcus",
        "fighter_id": "gladiator_1",
        "enemy": "Rival de prueba",
        "event_type": "official",
        "event_name": "Duelo de prueba",
        "rounds": 4
    }
    var invalid_entry: Dictionary = {
        "day": 0,
        "fighter": "",
        "enemy": "",
        "rounds": -1
    }
    var duplicate_entry: Dictionary = valid_entry.duplicate(true)
    var future_entry: Dictionary = valid_entry.duplicate(true)
    future_entry["day"] = 9

    var raw_entries: Array = [
        valid_entry,
        invalid_entry,
        duplicate_entry,
        future_entry,
        "dato corrupto"
    ]
    var sanitized: Array[Dictionary] = HistoryIntegrityValidator.sanitize(raw_entries, 60, 5)
    assert(sanitized.size() == 1)
    assert(int(sanitized[0].get("day", 0)) == 3)

    var report: Dictionary = HistoryIntegrityValidator.validate(sanitized, 5)
    assert(bool(report.get("valid", false)))
    assert(int(report.get("invalid_entries", -1)) == 0)
    assert(int(report.get("future_entries", -1)) == 0)
    assert(int(report.get("duplicate_entries", -1)) == 0)

    var duplicate_report_entries: Array[Dictionary] = [valid_entry, duplicate_entry]
    var duplicate_report: Dictionary = HistoryIntegrityValidator.validate(duplicate_report_entries, 5)
    assert(not bool(duplicate_report.get("valid", true)))
    assert(int(duplicate_report.get("duplicate_entries", 0)) == 1)

    var future_entries: Array[Dictionary] = [future_entry]
    var future_report: Dictionary = HistoryIntegrityValidator.validate(future_entries, 5)
    assert(not bool(future_report.get("valid", true)))
    assert(int(future_report.get("future_entries", 0)) == 1)

    print("HistoryIntegrityValidator tests passed")
    quit(0)
