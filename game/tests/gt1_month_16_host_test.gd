extends Node

const GT1Month16HostScript = preload("res://scripts/combat/gt1_month_16_host.gd")


func run() -> void:
	DataRepository.load_all()
	_test_human_request_allows_independent_gladiators()
	_test_request_requires_three_player_and_rival_entries()
	_test_manual_beast_snapshot_is_rejected()
	_test_canonical_beast_request_builds_snapshots()
	_test_unknown_beast_id_fails_closed()
	_test_contract_freezes_month_xvi_rules()
	print("GT I Month XVI host tests passed")


func _test_human_request_allows_independent_gladiators() -> void:
	var host = GT1Month16HostScript.new()
	var result: Dictionary = (
		host
		. prepare_human_request(
			["player_1", "player_2", "player_3"],
			"player_team",
			[
				_fighter("rival_1", "rival_team"),
				_fighter("rival_2", "rival_team"),
				_fighter("rival_3", "rival_team"),
			],
		)
	)
	assert(result.get("status") == "ready")
	assert(int(result.get("month", 0)) == 16)
	assert(result.get("format") == "1v1")
	assert(result.get("player_ids_by_bout") == [["player_1"], ["player_2"], ["player_3"]])
	assert((result.get("opponent_fighters_by_bout", []) as Array).size() == 3)
	assert(result.get("independent_bouts") == true)
	assert(result.get("carryover") == [])
	assert(result.get("human_selection_ready") == true)
	assert(result.get("beasts_allowed_by_design") == true)
	assert(result.get("beast_selection_ready") == true)
	assert(int(result.get("max_points", 0)) == 9)


func _test_request_requires_three_player_and_rival_entries() -> void:
	var host = GT1Month16HostScript.new()
	var result: Dictionary = (
		host
		. prepare_human_request(
			["player_1"],
			"player_team",
			[_fighter("rival_1", "rival_team")],
		)
	)
	assert(result.get("status") == "rejected")
	assert(_contains_error(result, "one explicit player gladiator id per bout"))
	assert(_contains_error(result, "exactly three explicit opponent fighter snapshots"))


func _test_manual_beast_snapshot_is_rejected() -> void:
	var host = GT1Month16HostScript.new()
	var beast := _fighter("lion_1", "rival_team")
	beast["beast_id"] = "lion"
	beast["entity_type"] = "beast"
	var result: Dictionary = (
		host
		. prepare_human_request(
			["player_1", "player_2", "player_3"],
			"player_team",
			[
				_fighter("rival_1", "rival_team"),
				beast,
				_fighter("rival_3", "rival_team"),
			],
		)
	)
	assert(result.get("status") == "rejected")
	assert(_contains_error(result, "manual beast snapshots are forbidden"))
	var readiness: Dictionary = result.get("beast_readiness", {}) as Dictionary
	assert(readiness.get("month") == 16)
	assert(readiness.get("canonical_beast_stats_ready") == true)
	assert(readiness.get("runtime_beast_adapter_ready") == true)
	assert(readiness.get("beast_selection_ready") == true)


func _test_canonical_beast_request_builds_snapshots() -> void:
	var host = GT1Month16HostScript.new()
	var result: Dictionary = (
		host
		. prepare_beast_request(
			["player_1", "player_2", "player_3"],
			"player_team",
			["boar", "lion", "bear"],
			"beast_team",
		)
	)
	assert(result.get("status") == "ready")
	assert(result.get("beast_selection_ready") == true)
	var bouts := result.get("opponent_fighters_by_bout", []) as Array
	assert(bouts.size() == 3)
	var expected_ids := ["boar", "lion", "bear"]
	for index in range(bouts.size()):
		var fighters := bouts[index] as Array
		assert(fighters.size() == 1)
		var beast := fighters[0] as Dictionary
		assert(beast.get("beast_id") == expected_ids[index])
		assert(beast.get("entity_type") == "beast")
		assert(beast.get("team") == "beast_team")
		assert(beast.get("can_block") == false)
		assert(beast.get("can_parry") == false)
		assert(beast.get("equipment") == {"power": 0, "defense": 0})


func _test_unknown_beast_id_fails_closed() -> void:
	var host = GT1Month16HostScript.new()
	var result: Dictionary = (
		host
		. prepare_beast_request(
			["player_1", "player_2", "player_3"],
			"player_team",
			["boar", "dragon", "bear"],
			"beast_team",
		)
	)
	assert(result.get("status") == "rejected")
	assert(_contains_error(result, "Unknown canonical Combat V1 beast id"))


func _test_contract_freezes_month_xvi_rules() -> void:
	var contract: Dictionary = GT1Month16HostScript.new().get_contract()
	assert(int(contract.get("month", 0)) == 16)
	assert(contract.get("format") == "1v1")
	assert(int(contract.get("bouts", 0)) == 3)
	assert(contract.get("independent_bouts") == true)
	assert(contract.get("carryover") == [])
	assert(contract.get("beasts_allowed_by_design") == true)
	assert(contract.get("beast_selection_boundary") == "gt1_beast_readiness_contract")
	assert(contract.get("beast_selection_current_behavior") == "canonical_beast_adapter_ready")
	assert(contract.get("manual_beast_snapshot_allowed") == false)
	assert(contract.get("human_selection_remains_available") == true)
	assert(contract.get("invent_beast_stats_allowed") == false)
	assert(int(contract.get("points_per_win", 0)) == 3)
	assert(int(contract.get("max_points", 0)) == 9)
	assert(contract.get("combat_authority") == "combat_simulator")
	assert(contract.get("scoring_authority") == "tournament_manager")
	assert(contract.get("rival_generation_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"current_pv": 100,
		"stamina": 100.0,
		"equipment": {"power": 0, "defense": 0},
	}


func _contains_error(result: Dictionary, fragment: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
