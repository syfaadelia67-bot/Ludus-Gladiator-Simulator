extends Node


func run() -> void:
	var arena := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
	var runtime := FileAccess.get_file_as_string("res://scripts/ui/combat_v1_arena_runtime.gd")
	var setup := FileAccess.get_file_as_string("res://scripts/ui/gt1_series_setup_panel.gd")
	var scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")

	assert(arena.contains("CombatV1ArenaRuntimeScript"))
	assert(arena.contains("RIVAL GT I CANÓNICO"))
	assert(arena.contains("Elegí un Ludus y los perfiles Combat V1"))
	assert(arena.contains("GT1SeriesSetupPanelScene"))
	assert(arena.contains("_arena_runtime.get_active_enemy_ids(_session)"))
	assert(not arena.contains("CombatManager.get_current_opponent_preview"))
	assert(not arena.contains("RivalUniqueGladiatorController"))
	assert(
		runtime.contains(
			'"human_opponent_selection_authority": "gt1_rival_combat_snapshot_provider"'
		)
	)
	assert(
		runtime.contains(
			'"player_facing_rival_catalog": "DataRepository.rival_combat_v1_snapshots"'
		)
	)
	assert(runtime.contains('"month_16_beast_selection_authority": "combat_beast_fighter_adapter"'))
	assert(runtime.contains('"generated_opponents_allowed": false'))
	assert(runtime.contains('"default_target_allowed": false'))
	assert(setup.contains('"explicit_selection_required": true'))
	assert(setup.contains('"generated_opponents_allowed": false'))
	assert(scene.contains('name="OpponentInfo"') or scene.contains('name = "OpponentInfo"'))
	assert(scene.contains('name="EnemyHealth"') or scene.contains('name = "EnemyHealth"'))
	print("Arena Combat V1 canonical opponent setup preview contract: OK")
