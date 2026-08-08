extends Node

const EstateManagerScript = preload("res://scripts/systems/estate_manager.gd")

func _ready() -> void:
    var estate = EstateManagerScript.new()
    estate._ensure_catalog_loaded()

    assert(estate.BUILDINGS.size() == 13, "The legacy estate catalog must define exactly 13 buildings until Part 3 canonicalization")
    assert(estate.canonicalize_building_id("quarters") == "barracks", "Legacy quarters id must migrate to barracks")
    assert(estate.canonicalize_building_id("guard_post") == "wall_and_gate", "Legacy guard_post id must migrate to wall_and_gate")
    assert(estate.canonicalize_building_id("security") == "wall_and_gate", "Legacy security id must migrate to wall_and_gate")

    var migrated := estate.migrate_levels({
        "quarters": 2,
        "barracks": 1,
        "guard_post": 3,
        "unknown_building": 9
    })
    assert(int(migrated.get("barracks", -1)) == 2, "Migration must keep the highest compatible barracks level")
    assert(int(migrated.get("wall_and_gate", -1)) == 3, "Legacy security levels must migrate to wall_and_gate")
    assert(not migrated.has("unknown_building"), "Unknown legacy ids must not enter canonical saves")
    assert(migrated.size() == 13, "Migrated estate state must contain every legacy canonical building before Part 3 canonicalization")

    estate.levels = migrated
    estate.demo_mode = true
    assert(estate.is_demo_available("forge"), "Forge must be available in the demo")
    assert(not estate.is_demo_available("stable"), "Stable must remain locked in the legacy demo catalog")
    assert(estate.get_effective_max_level("forge") == 3, "Demo buildings must allow progression through level 3")
    assert(estate.get_effective_max_level("stable") == 0, "Locked demo buildings must remain at level 0")

    estate.demo_mode = false
    assert(estate.get_effective_max_level("forge") == 10, "Full game buildings must preserve level 10 progression")
    assert(estate.get_effective_max_level("stable") == 10, "Legacy locked content must preserve its full-game level cap until Part 3 canonicalization")

    estate.free()
    print("Estate catalog tests passed")
    get_tree().quit(0)
