extends Node

const GT1PodiumTiebreakContractScript = preload(
	"res://scripts/combat/gt1_podium_tiebreak_contract.gd"
)


func _ready() -> void:
	var contract = GT1PodiumTiebreakContractScript.new()
	_test_exact_championship_tie_is_ready(contract)
	_test_other_podium_tie_shapes_stay_pending(contract)
	_test_player_win_resolves_gold_without_points(contract)
	_test_rival_win_resolves_silver_without_points(contract)
	_test_double_ko_requires_rematch(contract)
	_test_contract(contract)
	print("GT I podium tiebreak contract: OK")
	get_tree().quit(0)


func _test_exact_championship_tie_is_ready(contract) -> void:
	var request: Dictionary = contract.build_request(_policy_result(), _standings())
	assert(request.get("status") == "ready")
	assert(request.get("format") == "1v1")
	assert(request.get("participant_ludus_ids") == ["player", "cassianus"])
	assert(request.get("player_selection") == "one_available_gladiator")
	assert(request.get("rival_selection") == "one_available_gladiator")
	assert(request.get("allows_beasts") == false)
	assert(int(request.get("points_awarded", -1)) == 0)
	assert(request.get("combat_result_authority") == "CombatSimulator")
	assert(request.get("standings_authority") == "TournamentManager")


func _test_other_podium_tie_shapes_stay_pending(contract) -> void:
	var non_perfect := _standings()
	(non_perfect[0] as Dictionary)["points"] = 24
	(non_perfect[0] as Dictionary)["wins"] = 8
	(non_perfect[1] as Dictionary)["points"] = 24
	(non_perfect[1] as Dictionary)["wins"] = 8
	var non_perfect_request: Dictionary = contract.build_request(_policy_result(), non_perfect)
	assert(non_perfect_request.get("status") == "pending_exact_rule")

	var three_way_policy := _policy_result()
	three_way_policy["tied_rival_ids"] = ["cassianus", "flavianus"]
	three_way_policy["last_tied_position"] = 3
	var three_way_request: Dictionary = contract.build_request(three_way_policy, _standings())
	assert(three_way_request.get("status") == "pending_exact_rule")


func _test_player_win_resolves_gold_without_points(contract) -> void:
	var resolution: Dictionary = (
		contract
		. resolve_combat_result(
			contract.build_request(_policy_result(), _standings()),
			{
				"status": "combat_finished",
				"outcome": "team_win",
				"winner_team_id": "alpha",
			},
			{"alpha": "player", "beta": "cassianus"},
		)
	)
	assert(resolution.get("status") == "resolved")
	assert(int(resolution.get("placement", 0)) == 1)
	assert(resolution.get("medal") == "gold")
	assert(resolution.get("winner_ludus_id") == "player")
	assert(int(resolution.get("points_awarded", -1)) == 0)
	assert(resolution.get("resolution_source") == "tournament_characteristic_combat")


func _test_rival_win_resolves_silver_without_points(contract) -> void:
	var resolution: Dictionary = (
		contract
		. resolve_combat_result(
			contract.build_request(_policy_result(), _standings()),
			{
				"status": "combat_finished",
				"outcome": "team_win",
				"winner_team_id": "beta",
			},
			{"alpha": "player", "beta": "cassianus"},
		)
	)
	assert(resolution.get("status") == "resolved")
	assert(int(resolution.get("placement", 0)) == 2)
	assert(resolution.get("medal") == "silver")
	assert(resolution.get("winner_ludus_id") == "cassianus")
	assert(int(resolution.get("points_awarded", -1)) == 0)


func _test_double_ko_requires_rematch(contract) -> void:
	var resolution: Dictionary = (
		contract
		. resolve_combat_result(
			contract.build_request(_policy_result(), _standings()),
			{
				"status": "combat_finished",
				"outcome": "double_ko",
				"winner_team_id": "",
			},
			{"alpha": "player", "beta": "cassianus"},
		)
	)
	assert(resolution.get("status") == "rematch_required")
	assert(resolution.get("reason") == "double_ko")
	assert(int(resolution.get("placement", -1)) == 0)
	assert(str(resolution.get("medal", "x")).is_empty())
	assert(int(resolution.get("points_awarded", -1)) == 0)
	assert(resolution.get("applied_to_tournament_manager") == false)


func _test_contract(contract) -> void:
	var frozen: Dictionary = contract.get_contract()
	assert(frozen.get("supported_tie") == "two_ludi_tied_first_at_27_points")
	assert(frozen.get("format") == "1v1")
	assert(frozen.get("selection_per_ludus") == "one_available_gladiator")
	assert(frozen.get("beasts_allowed") == false)
	assert(frozen.get("points_awarded") == 0)
	assert(frozen.get("winner") == "champion")
	assert(frozen.get("double_ko") == "rematch_required")
	assert(frozen.get("other_podium_ties") == "pending_exact_rule")
	assert(frozen.get("winner_rng_allowed") == false)


func _policy_result() -> Dictionary:
	return {
		"status": "podium_combat_required",
		"reason": "podium_tie",
		"errors": [],
		"placement": 0,
		"medal": "",
		"tied_rival_ids": ["cassianus"],
		"first_tied_position": 1,
		"last_tied_position": 2,
		"requires_combat_tiebreak": true,
		"requires_non_podium_data": false,
		"resolution_source": "tournament_characteristic_combat",
	}


func _standings() -> Array:
	return [
		_entry("player", 27, 9),
		_entry("cassianus", 27, 9),
		_entry("flavianus", 21, 7),
		_entry("drusus", 18, 6),
		_entry("aurelius", 15, 5),
		_entry("severus", 12, 4),
		_entry("marcellus", 9, 3),
		_entry("varro", 6, 2),
	]


func _entry(entry_id: String, points: int, wins: int) -> Dictionary:
	return {
		"id": entry_id,
		"name": entry_id,
		"points": points,
		"wins": wins,
	}
