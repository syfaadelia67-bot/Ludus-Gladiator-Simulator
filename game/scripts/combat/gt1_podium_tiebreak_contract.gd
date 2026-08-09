extends RefCounted

const PLAYER_LUDUS_ID := "player"
const GT1_ID := "grand_tournament_rome"
const PERFECT_POINTS := 27
const PERFECT_WINS := 9


func build_request(policy_result: Dictionary, standings: Array) -> Dictionary:
	var errors := _validate_supported_tie(policy_result, standings)
	if not errors.is_empty():
		return _pending_exact_rule(errors)

	var tied_rival_ids := policy_result.get("tied_rival_ids", []) as Array
	var rival_id := str(tied_rival_ids[0])
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"tournament_id": GT1_ID,
		"tie_scope": "first_place_two_ludi_perfect_score",
		"format": "1v1",
		"participant_ludus_ids": [PLAYER_LUDUS_ID, rival_id],
		"player_ludus_id": PLAYER_LUDUS_ID,
		"rival_ludus_id": rival_id,
		"player_selection": "one_available_gladiator",
		"rival_selection": "one_available_gladiator",
		"allows_beasts": false,
		"points_awarded": 0,
		"decisive_winner_required": true,
		"double_ko_resolution": "rematch_required",
		"combat_result_authority": "CombatSimulator",
		"standings_authority": "TournamentManager",
	}


func resolve_combat_result(
	request: Dictionary, combat_result: Dictionary, team_to_ludus: Dictionary
) -> Dictionary:
	if str(request.get("status", "")) != "ready":
		return _rejected("invalid_tiebreak_request", ["Podium tiebreak request is not ready"])
	if str(combat_result.get("status", "")) != "combat_finished":
		return _rejected(
			"combat_not_finished",
			["Podium tiebreak requires a finished CombatSimulator result"],
		)

	var outcome := str(combat_result.get("outcome", ""))
	if outcome == "double_ko":
		return {
			"status": "rematch_required",
			"reason": "double_ko",
			"errors": [],
			"placement": 0,
			"medal": "",
			"points_awarded": 0,
			"resolution_source": "tournament_characteristic_combat",
			"applied_to_tournament_manager": false,
		}
	if outcome != "team_win":
		return _rejected(
			"non_decisive_combat_result",
			["Podium tiebreak requires a decisive team_win result"],
		)

	var winner_team_id := str(combat_result.get("winner_team_id", ""))
	var winner_ludus_id := str(team_to_ludus.get(winner_team_id, ""))
	var participants := request.get("participant_ludus_ids", []) as Array
	if winner_ludus_id.is_empty() or not participants.has(winner_ludus_id):
		return _rejected(
			"unknown_tiebreak_winner",
			["Combat winner team is not mapped to a participating Ludus"],
		)

	var player_won := winner_ludus_id == PLAYER_LUDUS_ID
	return {
		"status": "resolved",
		"reason": "",
		"errors": [],
		"placement": 1 if player_won else 2,
		"medal": "gold" if player_won else "silver",
		"winner_ludus_id": winner_ludus_id,
		"points_awarded": 0,
		"requires_combat_tiebreak": false,
		"requires_non_podium_data": false,
		"resolution_source": "tournament_characteristic_combat",
		"applied_to_tournament_manager": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"supported_tie": "two_ludi_tied_first_at_27_points",
		"format": "1v1",
		"selection_per_ludus": "one_available_gladiator",
		"beasts_allowed": false,
		"points_awarded": 0,
		"winner": "champion",
		"loser_placement": 2,
		"double_ko": "rematch_required",
		"other_podium_ties": "pending_exact_rule",
		"combat_result_authority": "CombatSimulator",
		"standings_authority": "TournamentManager",
		"winner_rng_allowed": false,
	}


func _validate_supported_tie(policy_result: Dictionary, standings: Array) -> Array[String]:
	var errors: Array[String] = []
	if str(policy_result.get("status", "")) != "podium_combat_required":
		errors.append("Standings policy did not request a podium combat")
	if str(policy_result.get("resolution_source", "")) != "tournament_characteristic_combat":
		errors.append("Podium tie must use tournament_characteristic_combat")
	if (
		int(policy_result.get("first_tied_position", 0)) != 1
		or int(policy_result.get("last_tied_position", 0)) != 2
	):
		errors.append("Only the frozen two-Ludus first-place tie is supported")

	var tied_rival_ids := policy_result.get("tied_rival_ids", []) as Array
	if tied_rival_ids.size() != 1:
		errors.append("Frozen championship tiebreak requires exactly one tied rival Ludus")
		return errors
	var rival_id := str(tied_rival_ids[0])
	if rival_id.is_empty() or rival_id == PLAYER_LUDUS_ID:
		errors.append("Frozen championship tiebreak requires one valid rival Ludus id")
		return errors

	var player_entry := _find_entry(standings, PLAYER_LUDUS_ID)
	var rival_entry := _find_entry(standings, rival_id)
	if player_entry.is_empty() or rival_entry.is_empty():
		errors.append("Championship tiebreak participants must exist in GT I standings")
		return errors
	if (
		int(player_entry.get("points", -1)) != PERFECT_POINTS
		or int(player_entry.get("wins", -1)) != PERFECT_WINS
		or int(rival_entry.get("points", -1)) != PERFECT_POINTS
		or int(rival_entry.get("wins", -1)) != PERFECT_WINS
	):
		errors.append("Frozen championship tiebreak requires both Ludi at 27 points / 9 wins")
	return errors


func _find_entry(standings: Array, entry_id: String) -> Dictionary:
	for raw_entry in standings:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		if str(entry.get("id", "")) == entry_id:
			return entry
	return {}


func _pending_exact_rule(errors: Array[String]) -> Dictionary:
	return {
		"status": "pending_exact_rule",
		"reason": "unsupported_podium_tie_shape",
		"errors": errors.duplicate(),
		"tournament_id": GT1_ID,
		"format": "",
		"points_awarded": 0,
		"combat_result_authority": "CombatSimulator",
		"standings_authority": "TournamentManager",
	}


func _rejected(reason: String, errors: Array[String]) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"placement": 0,
		"medal": "",
		"points_awarded": 0,
		"resolution_source": "tournament_characteristic_combat",
		"applied_to_tournament_manager": false,
	}
