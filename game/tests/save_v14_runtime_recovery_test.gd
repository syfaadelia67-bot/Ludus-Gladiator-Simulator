extends Node


func run() -> void:
	_test_old_v14_partial_gt1_recovers_without_inventing_state()
	_test_corrupt_runtime_section_is_rejected()
	_reset_runtime()
	print("Save v14 Combat V1 recovery tests passed")


func _test_old_v14_partial_gt1_recovers_without_inventing_state() -> void:
	_reset_runtime()
	GameState.day = 13
	assert(not TournamentManager.register_grand_tournament_fight_result(true, 13).is_empty())
	assert(not TournamentManager.register_grand_tournament_fight_result(false, 13).is_empty())
	var old_v14_payload := SaveManager._build_payload()
	old_v14_payload.erase("combat_v1_runtime")
	assert(int(old_v14_payload.get("version", 0)) == 14)
	assert(SaveManager._validate_payload(old_v14_payload))

	_reset_runtime()
	assert(SaveManager._apply_payload(old_v14_payload))
	var report := CombatV1SessionStore.get_last_import_report()
	assert(bool(report.get("legacy_partial_gt1_recovered", false)))
	assert(CombatV1SessionStore.get_gt1_session(13).is_empty())
	var summary := TournamentManager.get_gt1_summary()
	assert(int((summary.get("encounter_progress", {}) as Dictionary).get("13", -1)) == 0)
	assert(int(summary.get("player_bouts", -1)) == 0)
	assert(int(summary.get("player_points", -1)) == 0)
	assert((TournamentManager.export_state().get("history", []) as Array).is_empty())


func _test_corrupt_runtime_section_is_rejected() -> void:
	_reset_runtime()
	var payload := SaveManager._build_payload()
	payload["combat_v1_runtime"] = ["invalid"]
	assert(not SaveManager._validate_payload(payload))


func _reset_runtime() -> void:
	CombatV1SessionStore.clear_all()
	TournamentManager.import_state({})
	GameState.day = 1
