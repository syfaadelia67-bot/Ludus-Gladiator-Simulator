extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var progression_source := FileAccess.get_file_as_string("res://scripts/ui/progression_panel.gd")
    var equipment_source := FileAccess.get_file_as_string("res://scripts/ui/equipment_panel.gd")
    var progression_scene := FileAccess.get_file_as_string("res://scenes/ProgressionPanel.tscn")

    assert(progression_source.contains("Puntos de habilidad"), "Progression UI must show skill points")
    assert(progression_source.contains("person.technique"), "Progression UI must show technique")
    assert(progression_source.contains("person.health"), "Progression UI must show health")
    assert(progression_source.contains("PRÓXIMAMENTE"), "Progression UI must preview locked level III")
    assert(not progression_source.contains("technique_points"), "Active progression UI must not use legacy technique points")
    assert(not progression_source.contains("record.get(\"techniques\""), "Active progression UI must not read legacy techniques")
    assert(not progression_scene.contains("TechniqueSelector"), "Progression scene must use canonical ability controls")

    assert(equipment_source.contains("GladiatorProgressionManager.get_record"), "Equipment UI must read canonical progression")
    assert(equipment_source.contains("Puntos de habilidad"), "Equipment UI must show skill points")
    assert(equipment_source.contains("person.technique"), "Equipment UI must show technique")
    assert(equipment_source.contains("person.health"), "Equipment UI must show health")
    assert(equipment_source.contains("PRÓXIMAMENTE"), "Equipment UI must preview locked level III")

    print("Canonical gladiator UI contract tests passed")
    quit(0)
