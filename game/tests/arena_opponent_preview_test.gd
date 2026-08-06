extends Node

func run() -> void:
    var combat := FileAccess.get_file_as_string("res://scripts/systems/combat_manager_weekly.gd")
    var arena := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")

    assert(combat.contains("func get_current_opponent_preview"))
    assert(combat.contains("RivalUniqueGladiatorController.get_opponent_for_week"))
    assert(combat.contains("Bestia no revelada"))
    assert(combat.contains("GladiatorRivalryController.get_rivalry"))
    assert(arena.contains("func _refresh_encounter()"))
    assert(arena.contains("CombatManager.get_current_opponent_preview(selected_fighter_id)"))
    assert(arena.contains("GladiatorRivalryController.rivalry_changed.connect"))
    assert(arena.contains("Marcador personal"))
    assert(arena.contains("Vida estimada"))
    assert(scene.contains("name="OpponentInfo"") or scene.contains("name = "OpponentInfo""))
    print("Arena hosted opponent preview contract: OK")
