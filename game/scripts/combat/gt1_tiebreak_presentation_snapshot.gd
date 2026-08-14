extends RefCounted


func build(
	tournament_summary: Dictionary,
	standings_resolution: Dictionary,
	podium_request: Dictionary = {}
) -> Dictionary:
	if not bool(tournament_summary.get("tiebreak_required", false)):
		return _not_required(tournament_summary)

	var resolution_status := str(standings_resolution.get("status", ""))
	if resolution_status == "non_podium_data_required":
		return {
			"status": "non_podium_data_required",
			"reason": str(standings_resolution.get("reason", "non_podium_tie")),
			"errors": [],
			"requires_combat": false,
			"requires_external_rival_snapshot": false,
			"required_data": ["head_to_head", "prior_season_position"],
			"first_tied_position": int(standings_resolution.get("first_tied_position", 0)),
			"last_tied_position": int(standings_resolution.get("last_tied_position", 0)),
			"tied_rival_ids": (standings_resolution.get("tied_rival_ids", []) as Array).duplicate(),
			"presentation_may_resolve_standings": false,
		}

	if resolution_status != "podium_combat_required":
		return _pending_rule(
			"unresolved_tiebreak_state",
			standings_resolution.get("errors", []) as Array,
		)

	if str(podium_request.get("status", "")) != "ready":
		return _pending_rule(
			str(podium_request.get("reason", "unsupported_podium_tie_shape")),
			podium_request.get("errors", []) as Array,
		)

	var rival_id := str(podium_request.get("rival_ludus_id", ""))
	return {
		"status": "championship_tiebreak_ready",
		"reason": "",
		"errors": [],
		"format": str(podium_request.get("format", "1v1")),
		"player_ludus_id": str(podium_request.get("player_ludus_id", "player")),
		"rival_ludus_id": rival_id,
		"rival_ludus_name": _standings_name(tournament_summary, rival_id),
		"points_awarded": int(podium_request.get("points_awarded", 0)),
		"player_selection": str(podium_request.get("player_selection", "")),
		"rival_selection": str(podium_request.get("rival_selection", "")),
		"requires_combat": true,
		"requires_player_gladiator_selection": true,
		"requires_external_rival_snapshot": true,
		"rival_snapshot_source": "explicit_external_combat_v1_snapshot",
		"combat_authority": str(podium_request.get("combat_result_authority", "CombatSimulator")),
		"standings_authority": str(podium_request.get("standings_authority", "TournamentManager")),
		"double_ko_resolution": str(podium_request.get("double_ko_resolution", "rematch_required")),
		"presentation_may_resolve_standings": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"input": ["tournament_summary", "standings_resolution", "podium_request"],
		"output": "read_only_tiebreak_ui_snapshot",
		"exact_championship_tie": "two_ludi_tied_first_at_27_points",
		"championship_format": "1v1",
		"championship_points_awarded": 0,
		"rival_snapshot_source": "explicit_external_combat_v1_snapshot",
		"rival_generation_allowed": false,
		"combat_authority": "CombatSimulator",
		"standings_authority": "TournamentManager",
		"presentation_may_resolve_standings": false,
	}


func _not_required(summary: Dictionary) -> Dictionary:
	return {
		"status": "resolved" if bool(summary.get("standings_resolved", false)) else "not_required",
		"reason": "",
		"errors": [],
		"requires_combat": false,
		"requires_external_rival_snapshot": false,
		"presentation_may_resolve_standings": false,
	}


func _pending_rule(reason: String, errors: Array) -> Dictionary:
	return {
		"status": "pending_exact_rule",
		"reason": reason,
		"errors": errors.duplicate(),
		"requires_combat": false,
		"requires_external_rival_snapshot": false,
		"presentation_may_resolve_standings": false,
	}


func _standings_name(summary: Dictionary, rival_id: String) -> String:
	for raw_entry in summary.get("standings", []) as Array:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		if str(entry.get("id", "")) == rival_id:
			return str(entry.get("name", rival_id))
	return rival_id
