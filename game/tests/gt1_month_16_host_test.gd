extends Node

const GT1Month16HostScript = preload("res://scripts/combat/gt1_month_16_host.gd")


func run() -> void:
	_test_human_request_allows_independent_gladiators()
	_test_request_requires_three_player_and_rival_entries()
	_test_beast_path_fails_closed_while_readiness_is_blocked()
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
	assert(result.get("beast_selection_ready") == false)
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
	assert(_contains_error(result, "exactly three explicit rival fighter snapshots"))


func _test_beast_path_fails_closed_while_readiness_is_blocked() -> void:
	var host = GT1Month16HostScript.new()
	var beast := _fighter("lion_1", "rival_team")
	beast["beast_id"] = "lion"
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
	assert(_contains_error(result, "beast combat is blocked"))
	var readiness: Dictionary = result.get("beast_readiness", {}) as Dictionary
	assert(readiness.get("month") == 16)
	assert(readiness.get("beast_selection_ready") == false)
	assert(readiness.get("invent_stats_allowed") == false)
	assert(readiness.get("fallback_to_human_stats_allowed") == false)


func _test_contract_freezes_month_xvi_rules() -> void:
	var contract: Dictionary = GT1Month16HostScript.new().get_contract()
	assert(int(contract.get("month", 0)) == 16)
	assert(contract.get("format") == "1v1")
	assert(int(contract.get("bouts", 0)) == 3)
	assert(contract.get("independent_bouts") == true)
	assert(contract.get("carryover") == [])
	assert(contract.get("beasts_allowed_by_design") == true)
	assert(contract.get("beast_selection_boundary") == "gt1_beast_readiness_contract")
	assert(contract.get("human_fallback_allowed") == true)
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
