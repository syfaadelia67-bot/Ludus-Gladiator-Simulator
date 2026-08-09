extends SceneTree

const CombatEndResolverScript = preload("res://scripts/combat/combat_end_resolver.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_ongoing_when_both_teams_have_active_fighters()
	_test_team_win_when_one_team_is_eliminated()
	_test_double_ko_when_both_teams_are_eliminated()
	_test_contract_disables_automatic_surrender()

	if _failures.is_empty():
		print("Combat end resolver: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_ongoing_when_both_teams_have_active_fighters() -> void:
	var resolver = CombatEndResolverScript.new()
	var result: Dictionary = resolver.resolve(_state(10, 10))
	_assert_eq(result.get("status"), "resolved", "valid runtime state must resolve")
	_assert_eq(result.get("combat_finished"), false, "two active teams must keep combat running")
	_assert_eq(result.get("outcome"), "ongoing", "ongoing outcome must be explicit")
	_assert_eq(result.get("winner_team_id"), "", "ongoing combat has no winner")


func _test_team_win_when_one_team_is_eliminated() -> void:
	var resolver = CombatEndResolverScript.new()
	var result: Dictionary = resolver.resolve(_state(10, 0))
	_assert_eq(result.get("combat_finished"), true, "team elimination must finish combat")
	_assert_eq(result.get("outcome"), "team_win", "single surviving team must win")
	_assert_eq(result.get("winner_team_id"), "alpha", "surviving team must be winner")
	_assert_eq(result.get("loser_team_id"), "beta", "eliminated team must lose")
	_assert_eq(result.get("surrender_occurred"), false, "KO win must not be surrender")


func _test_double_ko_when_both_teams_are_eliminated() -> void:
	var resolver = CombatEndResolverScript.new()
	var result: Dictionary = resolver.resolve(_state(0, 0))
	_assert_eq(result.get("combat_finished"), true, "double elimination must finish combat")
	_assert_eq(result.get("outcome"), "double_ko", "double elimination must remain a draw outcome")
	_assert_eq(result.get("winner_team_id"), "", "double KO has no winner")
	_assert_eq(result.get("loser_team_id"), "", "double KO has no single loser")


func _test_contract_disables_automatic_surrender() -> void:
	var resolver = CombatEndResolverScript.new()
	var contract: Dictionary = resolver.get_contract()
	_assert_eq(contract.get("status"), "frozen", "combat-end contract must be frozen")
	_assert_eq(contract.get("automatic_surrender"), "disabled_v1", "V1 must not invent surrender")
	_assert_eq(contract.get("surrender_rng_allowed"), false, "surrender RNG must stay forbidden")


func _state(alpha_pv: int, beta_pv: int) -> Dictionary:
	return {
		"format": "1v1",
		"fighters": [
			_fighter("a", "alpha", alpha_pv),
			_fighter("b", "beta", beta_pv),
		],
	}


func _fighter(fighter_id: String, team_id: String, current_pv: int) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 10},
		"stamina": 10,
		"stamina_capacity": 10,
		"current_pv": current_pv,
		"vulnerable": false,
	}


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
