extends Node

const GT1RivalResultRegistryScript = preload("res://scripts/combat/gt1_rival_result_registry.gd")


func _ready() -> void:
	DataRepository.load_all()
	TournamentManager.import_state({})
	var registry = GT1RivalResultRegistryScript.new()

	var result := registry.register_result("cassianus", 18, 6)
	assert(result.get("status") == "registered")
	assert(result.get("rival_name") == "Ludus Cassianus")
	assert(result.get("identity_source") == "DataRepository.rival_ludi")
	assert(result.get("score_source") == "explicit_external_result")
	assert(result.get("generated_score") == false)
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

	TournamentManager.import_state({})
	print("Canonical GT I rival result registry: OK")
	get_tree().quit(0)
