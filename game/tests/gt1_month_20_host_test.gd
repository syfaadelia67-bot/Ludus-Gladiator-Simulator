extends Node

const GT1Month20HostScript = preload("res://scripts/combat/gt1_month_20_host.gd")


func run() -> void:
	_test_contract_freezes_month_xx_rules()
	_test_prepare_request_accepts_one_unilateral_substitution()
	_test_prepare_request_accepts_same_pair_all_three_bouts()
	_test_prepare_request_rejects_second_substitution()
	_test_prepare_request_rejects_invalid_rival_pair()
	print("GT I month XX host: OK")


func _test_contract_freezes_month_xx_rules() -> void:
	var host = GT1Month20HostScript.new()
	var contract: Dictionary = host.get_contract()
	assert(int(contract.get("month", 0)) == 20)
	assert(contract.get("format") == "2v2")
	assert(int(contract.get("bouts", 0)) == 3)
	assert(int(contract.get("team_size", 0)) == 2)
	assert(contract.get("roster_rule") == "same_pair_with_at_most_one_unilateral_substitution")
	assert(contract.get("carryover") == ["current_pv", "stamina"])
	assert(int(contract.get("substitution_limit", 0)) == 1)
	assert(contract.get("substitute_enters_fresh") == true)
	assert(contract.get("continuing_fighter_carries_state") == true)
	assert(contract.get("beasts_allowed") == false)
	assert(contract.get("combat_authority") == "combat_simulator")
	assert(contract.get("scoring_authority") == "tournament_manager")
	assert(contract.get("rival_generation_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _test_prepare_request_accepts_one_unilateral_substitution() -> void:
	var host = GT1Month20HostScript.new()
	var request: Dictionary = (
		host
		. prepare_request(
			[["p1", "p2"], ["p1", "p3"], ["p1", "p3"]],
			"player_team",
			_rival_pairs(),
		)
	)
	assert(request.get("status") == "ready")
	assert(request.get("player_ids_by_bout") == [["p1", "p2"], ["p1", "p3"], ["p1", "p3"]])
	assert(request.get("substitution_used") == true)
	assert(request.get("carryover") == ["current_pv", "stamina"])
	assert(int(request.get("max_points", 0)) == 9)


func _test_prepare_request_accepts_same_pair_all_three_bouts() -> void:
	var host = GT1Month20HostScript.new()
	var request: Dictionary = (
		host
		. prepare_request(
			[["p1", "p2"], ["p1", "p2"], ["p1", "p2"]],
			"player_team",
			_rival_pairs(),
		)
	)
	assert(request.get("status") == "ready")
	assert(request.get("substitution_used") == false)


func _test_prepare_request_rejects_second_substitution() -> void:
	var host = GT1Month20HostScript.new()
	var request: Dictionary = (
		host
		. prepare_request(
			[["p1", "p2"], ["p1", "p3"], ["p1", "p4"]],
			"player_team",
			_rival_pairs(),
		)
	)
	assert(request.get("status") == "rejected")
	assert(_contains_error(request, "at most one unilateral"))


func _test_prepare_request_rejects_invalid_rival_pair() -> void:
	var host = GT1Month20HostScript.new()
	var rivals := _rival_pairs()
	(rivals[1] as Array)[1] = _fighter("r2b", "another_rival_team")
	var request: Dictionary = (
		host
		. prepare_request(
			[["p1", "p2"], ["p1", "p2"], ["p1", "p2"]],
			"player_team",
			rivals,
		)
	)
	assert(request.get("status") == "rejected")
	assert(_contains_error(request, "one rival team"))


func _rival_pairs() -> Array:
	return [
		[_fighter("r1a", "rival_team"), _fighter("r1b", "rival_team")],
		[_fighter("r2a", "rival_team"), _fighter("r2b", "rival_team")],
		[_fighter("r3a", "rival_team"), _fighter("r3b", "rival_team")],
	]


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"stamina": 10.0,
		"equipment": {"power": 0, "defense": 0},
	}


func _contains_error(result: Dictionary, fragment: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
