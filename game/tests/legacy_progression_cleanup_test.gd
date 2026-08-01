extends Node

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var manager = GladiatorProgressionManager
    manager._load_catalogs()

    var old_record := {
        "level": 4,
        "specialization": "thraex",
        "technique_points": 2,
        "techniques": ["iron_guard", "brutal_finish"]
    }
    var migrated: Dictionary = manager._migrate_record(old_record)
    assert(str(migrated.get("specialization", "")) == "dimachaerus", "Thraex must migrate to Dimachaerus")
    assert(int(migrated.get("skill_points", -1)) == 2, "Legacy technique points must migrate to skill points")
    assert(not migrated.has("technique_points"), "Canonical records must not retain technique_points")
    assert(not migrated.has("techniques"), "Canonical records must not retain the legacy techniques array")
    assert(int(migrated.get("abilities", {}).get("feint", 0)) == 1, "Iron guard must migrate to Feint I")
    assert(int(migrated.get("abilities", {}).get("opportunity_strike", 0)) == 1, "Brutal finish must migrate to Opportunity Strike I")

    var balanced_record := manager._migrate_record({"specialization":"balanced"})
    assert(str(balanced_record.get("specialization", "")) == "gladiator", "Balanced must migrate to Gladiator")

    var panel_source := _read_text("res://scripts/ui/progression_panel.gd")
    var panel_scene := _read_text("res://scenes/ProgressionPanel.tscn")
    for legacy_text in ["\"balanced\"", "\"thraex\"", "technique_points", "record.get(\"techniques\"", "unlock_technique"]:
        assert(not panel_source.contains(legacy_text), "The active progression panel must not use legacy progression data: %s" % legacy_text)
    assert(not panel_scene.contains("TechniqueRow"), "The scene must expose abilities rather than legacy techniques")
    assert(panel_scene.contains("AbilityRow"), "The scene must contain the canonical ability controls")

    print("Legacy progression cleanup tests passed")
    get_tree().quit(0)

func _read_text(path: String) -> String:
    var file := FileAccess.open(path, FileAccess.READ)
    assert(file != null, "Required test file is missing: %s" % path)
    var content := file.get_as_text()
    file.close()
    return content
