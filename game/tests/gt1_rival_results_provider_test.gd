extends Node

const GT1RivalResultsProviderScript = preload("res://scripts/combat/gt1_rival_results_provider.gd")

const VALID_RESULTS := [
	{"rival_id": "cassianus", "points": 27, "wins": 9},
	{"rival_id": "flavianus", "points": 24, "wins": 8},
	{"rival_id": "drusus", "points": 21, "wins": 7},
	{"rival_id": "aurelius", "points": 18, "wins": 6},
	{"rival_id": "severus", "points": 15, "wins": 5},
	{"rival_id": "marcellus", "points": 12, "wins": 4},
	{"rival_id": "varro", "points": 9, "wins": 3},
]


func _ready() -> void:
	DataRepository.load_all()
	_test_complete_explicit_batch_registers_all_rivals()
	_test_invalid_batches_fail_before_registration()
	_test_contract()
	print("GT I explicit rival results provider: OK")
	get_tree().quit(0)


func _test_complete_explicit_batch_registers_all_rivals() -> void:
	TournamentManager.import_state({})
	var provider = GT1RivalResultsProviderScript.new()
	var validation: Dictionary = provider.validate_explicit_results(VALID_RESULTS)
	assert(validation.get("status") == "ready")
	assert((validation.get("normalized_results", []) as Array).size() == 7)
	assert(validation.get("score_source") == "explicit_external_results")
	assert(validation.get("generated_scores") == false)

	var registered: Dictionary = CampaignManager.register_gt1_rival_results(VALID_RESULTS)
	assert(registered.get("status") == "registered")
	assert(int(registered.get("registered_count", 0)) == 7)
	assert(registered.get("registration_authority") == "gt1_rival_result_registry")
	assert(registered.get("standings_authority") == "TournamentManager")
	assert(registered.get("generated_scores") == false)
	var summary := TournamentManager.get_gt1_summary()
	assert(int(summary.get("rival_results_registered", 0)) == 7)

	var repeated: Dictionary = CampaignManager.register_gt1_rival_results(VALID_RESULTS)
	assert(repeated.get("status") == "rejected")
	assert(repeated.get("reason") == "rival_results_already_registered")
	assert(int(TournamentManager.get_gt1_summary().get("rival_results_registered", 0)) == 7)
	TournamentManager.import_state({})


func _test_invalid_batches_fail_before_registration() -> void:
	TournamentManager.import_state({})

	var incomplete := VALID_RESULTS.duplicate(true)
	incomplete.pop_back()
	var incomplete_result: Dictionary = CampaignManager.register_gt1_rival_results(incomplete)
	assert(incomplete_result.get("status") == "rejected")
	assert(incomplete_result.get("reason") == "incomplete_rival_results_batch")
	assert(int(TournamentManager.get_gt1_summary().get("rival_results_registered", 0)) == 0)

	var duplicate := VALID_RESULTS.duplicate(true)
	duplicate[6] = duplicate[0].duplicate(true)
	var duplicate_result: Dictionary = CampaignManager.register_gt1_rival_results(duplicate)
	assert(duplicate_result.get("status") == "rejected")
	assert(duplicate_result.get("reason") == "duplicate_rival_result")
	assert(int(TournamentManager.get_gt1_summary().get("rival_results_registered", 0)) == 0)

	var inconsistent := VALID_RESULTS.duplicate(true)
	(inconsistent[2] as Dictionary)["points"] = 20
	var inconsistent_result: Dictionary = CampaignManager.register_gt1_rival_results(inconsistent)
	assert(inconsistent_result.get("status") == "rejected")
	assert(inconsistent_result.get("reason") == "inconsistent_rival_score")
	assert(int(TournamentManager.get_gt1_summary().get("rival_results_registered", 0)) == 0)

	var fractional := VALID_RESULTS.duplicate(true)
	(fractional[1] as Dictionary)["wins"] = 7.5
	var fractional_result: Dictionary = CampaignManager.register_gt1_rival_results(fractional)
	assert(fractional_result.get("status") == "rejected")
	assert(fractional_result.get("reason") == "invalid_rival_score_type")
	assert(int(TournamentManager.get_gt1_summary().get("rival_results_registered", 0)) == 0)
	TournamentManager.import_state({})


func _test_contract() -> void:
	var provider = GT1RivalResultsProviderScript.new()
	var contract: Dictionary = provider.get_contract()
	var campaign_contract: Dictionary = CampaignManager.get_gt1_rival_results_provider_contract()
	assert(campaign_contract == contract)
	assert(contract.get("status") == "frozen")
	assert(contract.get("provider_authority") == "gt1_rival_results_provider")
	assert(contract.get("input_source") == "explicit_external_results")
	assert(contract.get("registration_authority") == "gt1_rival_result_registry")
	assert(contract.get("standings_authority") == "TournamentManager")
	assert(contract.get("canonical_rival_source") == "DataRepository.rival_ludi")
	assert(int(contract.get("required_rival_results", 0)) == 7)
	assert(int(contract.get("points_per_win", 0)) == 3)
	assert(contract.get("full_batch_prevalidation_required") == true)
	assert(contract.get("partial_batch_allowed") == false)
	assert(contract.get("existing_result_overwrite_allowed") == false)
	assert(contract.get("generated_scores_allowed") == false)
	assert(contract.get("random_scores_allowed") == false)
	assert(contract.get("legacy_rival_manager_is_score_authority") == false)
	assert(contract.get("save_version_change_required") == false)
