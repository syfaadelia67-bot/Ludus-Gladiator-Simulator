extends Node

const GT1Month13HostScript = preload("res://scripts/combat/gt1_month_13_host.gd")


func run() -> void:
	_test_request_reuses_same_gladiator_for_all_bouts()
	_test_request_requires_three_explicit_rivals()
	_test_request_rejects_beasts()
	_test_contract_freezes_month_xiii_rules()
	print("GT I Month XIII host tests passed")


func _test_request_reuses_same_gladiator_for_all_bouts() -> void:
	var host = GT1Month13HostScript.new()
	var result: Dictionary = (
		host
		. prepare_request(
			"player_gladiator",
			"player_team",
			[
				_fighter("rival_1", "rival_team"),
				_fighter("rival_2", "rival_team"),
				_fighter("rival_3", "rival_team"),
			],
		)
	)
	assert(result.get("status") == "ready")
	assert(int(result.get("month", 0)) == 13)
	assert(result.get("format") == "1v1")
	assert(
		(
			result.get("player_ids_by_bout")
			== [
				["player_gladiator"],
				["player_gladiator"],
				["player_gladiator"],
			]
		)
	)
	assert((result.get("opponent_fighters_by_bout", []) as Array).size() == 3)
	assert(result.get("carryover") == ["current_pv", "stamina"])
	assert(result.get("beasts_allowed") == false)
	assert(int(result.get("max_points", 0)) == 9)


func _test_request_requires_three_explicit_rivals() -> void:
	var host = GT1Month13HostScript.new()
	var result: Dictionary = (
		host
		. prepare_request(
			"player_gladiator",
			"player_team",
			[_fighter("rival_1", "rival_team")],
		)
	)
	assert(result.get("status") == "rejected")
	assert(_contains_error(result, "exactly three explicit rival"))


func _test_request_rejects_beasts() -> void:
	var host = GT1Month13HostScript.new()
	var beast := _fighter("lion_1", "rival_team")
	beast["beast_id"] = "lion"
	var result: Dictionary = (
		host
		. prepare_request(
			"player_gladiator",
			"player_team",
			[
				_fighter("rival_1", "rival_team"),
				beast,
				_fighter("rival_3", "rival_team"),
			],
		)
	)
	assert(result.get("status") == "rejected")
	assert(_contains_error(result, "does not allow beasts"))


func _test_contract_freezes_month_xiii_rules() -> void:
	var contract: Dictionary = GT1Month13HostScript.new().get_contract()
	assert(int(contract.get("month", 0)) == 13)
	assert(contract.get("format") == "1v1")
	assert(int(contract.get("bouts", 0)) == 3)
	assert(contract.get("beasts_allowed") == false)
	assert(contract.get("consecutive") == true)
	assert(contract.get("carryover") == ["current_pv", "stamina"])
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
