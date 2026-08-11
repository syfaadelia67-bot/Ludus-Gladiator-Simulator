extends Node


func run() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var save_manager := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")
	var base_save := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")
	var store := FileAccess.get_file_as_string("res://scripts/systems/combat_v1_session_store.gd")
	var tournament := FileAccess.get_file_as_string(
		"res://scripts/systems/tournament_manager_demo_monthly.gd"
	)
	var arena := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
	var tiebreak := FileAccess.get_file_as_string(
		"res://scripts/combat/gt1_championship_tiebreak_catalog_runtime.gd"
	)
	var coordinator := FileAccess.get_file_as_string(
		"res://scripts/core/new_campaign_coordinator.gd"
	)
	var owner := FileAccess.get_file_as_string("res://scripts/systems/ludus_owner_manager.gd")
	var recovery := FileAccess.get_file_as_string(
		"res://scripts/core/save_recovery_coordinator.gd"
	)
	var inspector := FileAccess.get_file_as_string(
		"res://scripts/core/save_compatibility_inspector.gd"
	)
	var readiness := FileAccess.get_file_as_string(
		"res://scripts/core/demo_pre_asset_readiness.gd"
	)

	assert(base_save.contains("const SAVE_VERSION := 14"))
	assert(not base_save.contains("const SAVE_VERSION := 15"))
	assert(
		project.contains('CombatV1SessionStore="*res://scripts/systems/combat_v1_session_store.gd"')
	)
	assert(project.find("TournamentManager=") < project.find("CombatV1SessionStore="))
	assert(save_manager.contains('payload["combat_v1_runtime"] = CombatV1SessionStore.export_state()'))
	assert(save_manager.contains("CombatV1SessionStore.import_state"))
	assert(save_manager.contains('game_data["day"] = month'))
	assert(save_manager.contains('game_data["week"] = month'))
	assert(store.contains('"save_version": 14'))
	assert(store.contains('"save_shape": "additive_dictionary"'))
	assert(store.contains('"invent_missing_combat_state_allowed": false'))
	assert(store.contains("rollback_incomplete_gt1_encounter"))
	assert(tournament.contains("func rollback_incomplete_gt1_encounter"))
	assert(tournament.contains("matching_results.size() != completed"))
	assert(tournament.contains('"restart_incomplete_encounter_without_inventing_combat_state"'))
	assert(arena.contains("CombatV1SessionStore.set_gt1_session"))
	assert(arena.contains("CombatV1SessionStore.get_gt1_session"))
	assert(arena.contains("SaveManager.load_completed.connect"))
	assert(tiebreak.contains("CombatV1SessionStore.set_tiebreak_session"))
	assert(tiebreak.contains('"rematch_state_persisted": true'))
	assert(coordinator.contains("CombatV1SessionStore.clear_all()"))
	assert(coordinator.contains('"combat_v1_runtime": {}'))
	assert(owner.contains("CombatV1SessionStore.clear_all()"))
	assert(recovery.contains('runtime_report.get("legacy_partial_gt1_recovered", false)'))
	assert(recovery.contains("SaveManager.save_game()"))
	assert(inspector.contains('"month"'))
	assert(inspector.contains('"invalid_combat_v1_runtime"'))
	assert(not readiness.contains('"in_progress_combat_save_policy"'))
	assert(not arena.contains("CombatManager.simulate"))
	assert(not store.contains("CombatManager"))

	print("Save v14 Combat V1 persistence authority contract: OK")
