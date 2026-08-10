extends Node


func run() -> void:
	var arena := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
	var scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")

	assert(arena.contains("GameState.get_month()"))
	assert(arena.contains("TournamentManager.get_gt1_encounter"))
	assert(arena.contains("MES %d"))
	assert(arena.contains("XIII, XVI y XX"))
	assert(arena.contains("event_conditions.text"))
	assert(not arena.contains("FINAL_WEEK"))
	assert(not arena.contains("GameState.get_week()"))
	assert(not arena.contains("COMBATE FINAL DE LA DEMO"))
	assert(not arena.contains("CombatManager"))
	assert(scene.contains('name="EventConditions"') or scene.contains('name = "EventConditions"'))
	print("Arena monthly GT I event warning contract: OK")
