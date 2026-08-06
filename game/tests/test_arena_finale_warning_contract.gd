extends Node

func run() -> void:
    var arena := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
    var combat := FileAccess.get_file_as_string("res://scripts/systems/combat_manager_weekly.gd")
    var scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")

    assert(arena.contains("const FINAL_WEEK := 16"))
    assert(arena.contains("CampaignManager.get_summary()"))
    assert(arena.contains("final_combat_resolved"))
    assert(arena.contains("GameState.get_week() == FINAL_WEEK"))
    assert(arena.contains("COMBATE FINAL DE LA DEMO"))
    assert(arena.contains("event_conditions.text"))
    assert(combat.contains("const DEMO_FINAL_WEEK := 16"))
    assert(combat.contains("Victoria o derrota final de campaña"))
    assert(scene.contains("name="EventConditions"") or scene.contains("name = "EventConditions""))
    print("Arena hosted finale warning contract: OK")
