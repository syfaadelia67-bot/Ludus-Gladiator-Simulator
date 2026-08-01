extends Node

const PersonScript = preload("res://scripts/entities/person.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var save_manager = SaveManager
    var progression = GladiatorProgressionManager
    progression._load_catalogs()
    progression.records.clear()

    var person = PersonScript.new({
        "id":"save_v12_gladiator",
        "name":"Save Test",
        "role":"gladiator",
        "strength":8,
        "agility":9,
        "endurance":10,
        "intelligence":7,
        "technique":12,
        "health":85
    })

    var serialized: Dictionary = save_manager._serialize_person(person)
    assert(int(serialized.get("technique", -1)) == 12, "Save v12 must serialize technique")
    assert(int(serialized.get("health", -1)) == 85, "Save v12 must serialize health")

    var restored = save_manager._deserialize_person(serialized)
    assert(restored.technique == 12, "Save v12 must restore technique")
    assert(restored.health == 85, "Save v12 must restore health")

    var legacy_person_data := serialized.duplicate(true)
    legacy_person_data.erase("technique")
    legacy_person_data.erase("health")
    var migrated = save_manager._deserialize_person(legacy_person_data)
    assert(migrated.technique == 5, "Legacy saves must migrate missing technique to 5")
    assert(migrated.health == 50, "Legacy saves must migrate missing health to 50")

    RosterManager.people.clear()
    RosterManager.people.append(person)
    var record: Dictionary = progression.ensure_record(person.id)
    record["level"] = 4
    record["specialization"] = "retiarius"
    record["skill_points"] = 2
    record["abilities"] = {"precise_strike":2, "cast_net":1}
    record["tactical_plan"] = [
        {"ability_id":"cast_net", "condition":"opening"},
        {"ability_id":"precise_strike", "condition":"target_vulnerable"}
    ]

    var progression_state: Dictionary = progression.export_state()
    progression.records.clear()
    progression.import_state(progression_state)
    var restored_record: Dictionary = progression.get_record(person.id)

    assert(int(restored_record.get("skill_points", -1)) == 1, "Save migration must preserve the remaining unspent point after accounting for learned ability ranks")
    assert(int(restored_record.get("abilities", {}).get("precise_strike", 0)) == 2, "Ability level II must survive progression save/load")
    assert(int(restored_record.get("abilities", {}).get("cast_net", 0)) == 1, "Class ability level must survive progression save/load")
    assert(restored_record.get("tactical_plan", []).size() == 1, "Tactical plans must remove class abilities whose required equipment is absent")
    assert(str(restored_record.get("specialization", "")) == "retiarius", "Specialization must survive progression save/load")

    var legacy_progression := {
        "records": {
            person.id: {
                "level":3,
                "specialization":"thraex",
                "technique_points":1,
                "techniques":["precise_strike"]
            }
        },
        "retired_gladiators":[]
    }
    progression.import_state(legacy_progression)
    var migrated_record: Dictionary = progression.get_record(person.id)
    assert(str(migrated_record.get("specialization", "")) == "dimachaerus", "Legacy Thraex must migrate to Dimachaerus")
    assert(int(migrated_record.get("skill_points", -1)) == 1, "Legacy technique points must migrate to skill points")
    assert(int(migrated_record.get("abilities", {}).get("precise_strike", 0)) == 1, "Legacy techniques must migrate to abilities")

    print("Save v12 progression tests passed")
    get_tree().quit(0)
