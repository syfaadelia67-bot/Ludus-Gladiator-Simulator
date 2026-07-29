extends SceneTree

func _init() -> void:
    var valid_entry: Dictionary = {
        "day": 3,
        "fighter": "Marcus",
        "fighter_id": "gladiator_1",
        "enemy": "Rival de prueba",
        "event_type": "official",
        "rounds": 4
    }
    var invalid_entry: Dictionary = {
        "day": 0,
        "fighter": "",
        "enemy": "",
        "rounds": -1
    }
    var raw_entries: Array = [valid_entry, invalid_entry, "dato corrupto"]
    var sanitized: Array[Dictionary] = HistoryIntegrityValidator.sanitize(raw_entries)
    assert(sanitized.size() == 1)

    var report: Dictionary = HistoryIntegrityValidator.validate(sanitized, 5)
    assert(bool(report.get("valid", false)))
    assert(int(report.get("invalid_entries", -1)) == 0)
    assert(int(report.get("future_entries", -1)) == 0)

    var future_entries: Array[Dictionary] = [valid_entry.duplicate(true)]
    future_entries[0]["day"] = 9
    var future_report: Dictionary = HistoryIntegrityValidator.validate(future_entries, 5)
    assert(not bool(future_report.get("valid", true)))
    assert(int(future_report.get("future_entries", 0)) == 1)

    print("HistoryIntegrityValidator tests passed")
    quit(0)
