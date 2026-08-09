extends Node

const GT1RivalResultRegistryScript = preload("res://scripts/combat/gt1_rival_result_registry.gd")


func _ready() -> void:
	DataRepository.load_all()
	_test_explicit_rival_result_registration()
	_test_completed_standings_surface_non_podium_tiebreak_requirement()
	print("Canonical GT I rival result registry: OK")
	get_tree().quit(0)


func _test_explicit_rival_result_registration() -> void:
	TournamentManager.import_state({})
	var registry = GT1RivalResultRegistryScript.new()

	var result := registry.register_result("cassianus", 18, 6)
	assert(result.get("status") == "registered")
	assert(result.get("rival_name") == "Ludus Cassianus")
	assert(result.get("identity_source") == "DataRepository.rival_ludi")
	assert(result.get("score_source") == "explicit_external_result")
	assert(result.get("generated_score") == false)
	var pending := result.get("standings_resolution", {}) as Dictionary
	assert(pending.get("status") == "pending_results")
	assert(pending.get("reason") == "player_series_incomplete")
	assert(int(TournamentManager.get_gt1_summary().get("rival_results_registered", 0)) == 1)

	var unknown := registry.register_result("rival_legacy", 12, 4)
	assert(unknown.get("status") == "rejected")
	assert(unknown.get("reason") == "unknown_rival_ludus")
	assert(int(TournamentManager.get_gt1_summary().get("rival_results_registered", 0)) == 1)

	var inconsistent := registry.register_result("flavianus", 13, 4)
	assert(inconsistent.get("status") == "rejected")
	assert(inconsistent.get("reason") == "inconsistent_rival_score")
	assert(int(TournamentManager.get_gt1_summary().get("rival_results_registered", 0)) == 1)

	var contract := registry.get_contract()
	assert(contract.get("legacy_rival_manager_is_score_authority") == false)
	assert(contract.get("generated_score_allowed") == false)
	assert(contract.get("points_per_win") == 3)
	assert(contract.get("standings_resolution_policy") == "gt1_standings_tiebreak_policy")
	assert(contract.get("podium_tie_resolution") == "tournament_characteristic_combat")
	assert(contract.get("non_podium_tie_resolution") == ["head_to_head", "prior_season_position"])
	assert(contract.get("resolved_non_podium_tie_authority") == "TournamentManager")
	assert(contract.get("resolved_tiebreak_uses_existing_save_v14_fields") == true)
	assert(contract.get("alphabetical_fallback_allowed") == false)
	assert(contract.get("random_fallback_allowed") == false)

	TournamentManager.import_state({})


func _test_completed_standings_surface_non_podium_tiebreak_requirement() -> void:
	(
		TournamentManager
		. import_state(
			{
				"gt1_player_points": 18,
				"gt1_player_wins": 6,
				"gt1_player_bouts": 9,
				"gt1_encounter_progress": {"13": 3, "16": 3, "20": 3},
			}
		)
	)
	var registry = GT1RivalResultRegistryScript.new()
	var rival_results := [
		["aurelius", 27, 9],
		["flavianus", 24, 8],
		["drusus", 21, 7],
		["cassianus", 18, 6],
		["severus", 15, 5],
		["marcellus", 12, 4],
		["varro", 9, 3],
	]
	var final_result: Dictionary = {}
	for rival_result in rival_results:
		final_result = (
			registry
			. register_result(
				str(rival_result[0]),
				int(rival_result[1]),
				int(rival_result[2]),
			)
		)
		assert(final_result.get("status") == "registered")

	var resolution := final_result.get("standings_resolution", {}) as Dictionary
	assert(resolution.get("status") == "non_podium_data_required")
	assert(resolution.get("requires_combat_tiebreak") == false)
	assert(resolution.get("requires_non_podium_data") == true)
	assert(int(resolution.get("first_tied_position", 0)) == 4)
	assert(int(resolution.get("last_tied_position", 0)) == 5)
	assert(resolution.get("tied_rival_ids") == ["cassianus"])
	assert(resolution.get("resolution_source_contract") == "gt1_standings_tiebreak_policy")

	var unresolved_summary := TournamentManager.get_gt1_summary()
	assert(unresolved_summary.get("tiebreak_required") == true)
	assert(unresolved_summary.get("standings_resolved") == false)

	var resolved := (
		registry
		. evaluate_current_standings(
			{
				"cassianus": {"head_to_head_winner_id": "player"},
			}
		)
	)
	assert(resolved.get("status") == "resolved")
	assert(int(resolved.get("placement", 0)) == 4)
	assert(str(resolved.get("medal", "x")).is_empty())
	assert(resolved.get("resolution_source") == "head_to_head_then_prior_season_position")
	assert(resolved.get("resolution_source_contract") == "gt1_standings_tiebreak_policy")
	assert(resolved.get("applied_to_tournament_manager") == true)

	var resolved_summary := TournamentManager.get_gt1_summary()
	assert(resolved_summary.get("tiebreak_required") == false)
	assert(resolved_summary.get("standings_resolved") == true)
	assert(int(resolved_summary.get("placement", 0)) == 4)
	assert(str(resolved_summary.get("medal", "x")).is_empty())
	assert(TournamentManager.is_gt1_complete())

	var saved_state := TournamentManager.export_state()
	TournamentManager.import_state(saved_state)
	var restored_summary := TournamentManager.get_gt1_summary()
	assert(restored_summary.get("tiebreak_required") == false)
	assert(restored_summary.get("standings_resolved") == true)
	assert(int(restored_summary.get("placement", 0)) == 4)
	assert(str(restored_summary.get("medal", "x")).is_empty())

	TournamentManager.import_state({})
