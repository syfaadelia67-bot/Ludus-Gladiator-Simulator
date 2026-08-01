extends Node

func run() -> void:
    var manager_source := FileAccess.get_file_as_string("res://scripts/systems/combat_history_manager_weekly.gd")
    var panel_source := FileAccess.get_file_as_string("res://scripts/ui/combat_history_panel.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    assert(manager_source.contains("entries[0][\"week\"]"))
    assert(manager_source.contains("entries[0][\"day\"]"))
    assert(manager_source.contains("entry.get(\"week\", entry.get(\"day\", 1))"))
    assert(manager_source.contains("func import_state"))
    assert(manager_source.contains("func get_entries"))

    assert(project_source.contains("CombatHistoryManager=\"*res://scripts/systems/combat_history_manager_weekly.gd\""))
    assert(panel_source.contains("func _entry_week"))
    assert(panel_source.contains("Semana %d"))
    assert(not panel_source.contains("Día %d"))

    print("PASS: weekly combat history contract")
