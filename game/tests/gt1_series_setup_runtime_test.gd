extends Node

const GT1SeriesSetupRuntimeScript = preload("res://scripts/ui/gt1_series_setup_runtime.gd")


func run() -> void:
	DataRepository.load_all()
	_test_contract()
	_test_catalogs()
	_test_month_13_bridge()
	_test_month_16_bridge()
	_test_month_20_bridge()
	_test_fail_closed_selection()
	print("GT I series setup runtime: OK")


func _test_contract() -> void:
	var contract := GT1SeriesSetupRuntimeScript.new().get_contract()
	assert(contract.get("setup_authority") == "gt1_series_setup_runtime")
	assert(contract.get("combat_runtime") == "combat_v1_arena_runtime")
	assert(contract.get("human_opponent_selection_authority") == "gt1_rival_combat_snapshot_provider")
	assert(contract.get("rival_catalog") == "DataRepository.rival_combat_v1_snapshots")
	assert(contract.get("rival_ludi") == "DataRepository.rival_ludi")
	assert(contract.get("month_16_beast_catalog") == "DataRepository.beasts")
	assert(contract.get("explicit_series_selection_required") == true)
	assert(contract.get("generated_opponents_allowed") == false)
	assert(contract.get("combat_authority") == "combat_simulator")
	assert(contract.get("scoring_authority") == "tournament_manager")
	assert(contract.get("save_version_change_required") == false)


func _test_catalogs() -> void:
	var runtime = GT1SeriesSetupRuntimeScript.new()
	var month_13 := runtime.get_gt1_setup_catalog(13)
	assert(month_13.get("status") == "ready")
	assert(int(month_13.get("player_slots", 0)) == 1)
	assert(int(month_13.get("opponent_slots", 0)) == 3)
	assert(month_13.get("opponent_modes") == ["human"])
	assert((month_13.get("rivals", []) as Array).size() == 7)
	for raw_rival in month_13.get("rivals", []) as Array:
		assert(((raw_rival as Dictionary).get("fighters", []) as Array).size() == 3)

	var month_16 := runtime.get_gt1_setup_catalog(16)
	assert(month_16.get("status") == "ready")
	assert(int(month_16.get("player_slots", 0)) == 3)
	assert(int(month_16.get("opponent_slots", 0)) == 3)
	assert(month_16.get("opponent_modes") == ["human", "beast"])
	assert((month_16.get("beasts", []) as Array).size() == 3)

	var month_20 := runtime.get_gt1_setup_catalog(20)
	assert(month_20.get("status") == "ready")
	assert(int(month_20.get("player_slots", 0)) == 6)
	assert(int(month_20.get("opponent_slots", 0)) == 6)
	assert(month_20.get("opponent_modes") == ["human"])
	assert(month_20.get("generated_opponents_allowed") == false)


func _test_month_13_bridge() -> void:
	var request := GT1SeriesSetupRuntimeScript.new().prepare_month_13_request(
		"player", "alpha", "cassianus", ["rival_heavy", "rival_agile", "rival_technical"]
	)
	assert(request.get("status") == "ready")
	assert(request.get("player_ids_by_bout") == [["player"], ["player"], ["player"]])
	var bouts := request.get("opponent_fighters_by_bout", []) as Array
	assert(str(((bouts[0] as Array)[0] as Dictionary).get("id", "")) == "rival_heavy")
	assert(str(((bouts[1] as Array)[0] as Dictionary).get("id", "")) == "rival_agile")
	assert(str(((bouts[2] as Array)[0] as Dictionary).get("id", "")) == "rival_technical")


func _test_month_16_bridge() -> void:
	var request := GT1SeriesSetupRuntimeScript.new().prepare_month_16_human_request(
		["p1", "p2", "p3"],
		"alpha",
		"flavianus",
		["rival_technical", "rival_heavy", "rival_agile"],
	)
	assert(request.get("status") == "ready")
	assert(request.get("player_ids_by_bout") == [["p1"], ["p2"], ["p3"]])
	assert(request.get("independent_bouts") == true)
	assert(request.get("carryover") == [])


func _test_month_20_bridge() -> void:
	var request := GT1SeriesSetupRuntimeScript.new().prepare_month_20_request(
		[["p1", "p2"], ["p1", "p3"], ["p1", "p3"]],
		"alpha",
		"drusus",
		[
			["rival_heavy", "rival_agile"],
			["rival_heavy", "rival_technical"],
			["rival_agile", "rival_technical"],
		],
	)
	assert(request.get("status") == "ready")
	assert(request.get("format") == "2v2")
	assert(request.get("substitution_used") == true)
	var bouts := request.get("opponent_fighters_by_bout", []) as Array
	assert(bouts.size() == 3)
	for raw_bout in bouts:
		assert((raw_bout as Array).size() == 2)


func _test_fail_closed_selection() -> void:
	var runtime = GT1SeriesSetupRuntimeScript.new()
	var missing := runtime.prepare_month_13_request(
		"player", "alpha", "cassianus", ["rival_heavy", "", "rival_technical"]
	)
	assert(missing.get("status") == "rejected")
	assert(missing.get("generated_opponents_allowed") == false)
	var unknown := runtime.prepare_month_16_human_request(
		["p1", "p2", "p3"],
		"alpha",
		"unknown_ludus",
		["rival_heavy", "rival_agile", "rival_technical"],
	)
	assert(unknown.get("status") == "rejected")
	assert(unknown.get("generated_opponents_allowed") == false)
	assert(runtime.get_gt1_setup_catalog(12).get("status") == "rejected")
