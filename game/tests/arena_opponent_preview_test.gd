extends Node


func run() -> void:
	var arena := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
	var runtime := FileAccess.get_file_as_string("res://scripts/ui/combat_v1_arena_runtime.gd")
	var scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")

	assert(arena.contains("CombatV1ArenaRuntimeScript"))
	assert(arena.contains("RIVAL COMBAT V1"))
	assert(arena.contains("snapshot canónico explícito"))
	assert(arena.contains("La Arena no genera ni elige rivales"))
	assert(arena.contains("_arena_runtime.get_active_enemy_ids(_session)"))
	assert(not arena.contains("CombatManager.get_current_opponent_preview"))
	assert(not arena.contains("RivalUniqueGladiatorController"))
	assert(runtime.contains('"opponent_selection_authority": "external_explicit_snapshots"'))
	assert(runtime.contains('"default_target_allowed": false'))
	assert(scene.contains('name="OpponentInfo"') or scene.contains('name = "OpponentInfo"'))
	assert(scene.contains('name="EnemyHealth"') or scene.contains('name = "EnemyHealth"'))
	print("Arena Combat V1 explicit opponent preview contract: OK")
