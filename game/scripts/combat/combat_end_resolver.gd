extends RefCounted

const RuntimeStateBuilderScript = preload("res://scripts/combat/combat_runtime_state_builder.gd")

var _runtime_builder = RuntimeStateBuilderScript.new()


func resolve(state: Dictionary) -> Dictionary:
	var errors: Array[String] = _runtime_builder.validate_runtime_state(state)
	if not errors.is_empty():
		return _invalid(errors)

	var active_by_team: Dictionary = {}
	var all_teams: Array[String] = []
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		var team_id := str(fighter.get("team", ""))
		if not all_teams.has(team_id):
			all_teams.append(team_id)
		if not active_by_team.has(team_id):
			active_by_team[team_id] = 0
		if not _runtime_builder.is_knocked_out(fighter):
			active_by_team[team_id] = int(active_by_team[team_id]) + 1

	all_teams.sort()
	if all_teams.size() != 2:
		return _invalid(["Combat V1 end resolution requires exactly two teams"])

	var surviving_teams: Array[String] = []
	for team_id in all_teams:
		if int(active_by_team.get(team_id, 0)) > 0:
			surviving_teams.append(team_id)

	if surviving_teams.size() == 2:
		return _result(false, "ongoing", "", "", all_teams, [])
	if surviving_teams.is_empty():
		return _result(true, "double_ko", "", "", all_teams, all_teams)

	var winner_team_id := surviving_teams[0]
	var loser_team_id := all_teams[0] if all_teams[1] == winner_team_id else all_teams[1]
	return _result(true, "team_win", winner_team_id, loser_team_id, all_teams, [loser_team_id])


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"authority": "combat_simulator",
		"finish_condition": "team_elimination",
		"team_eliminated_when": "no_active_fighters",
		"double_ko_outcome": "double_ko",
		"automatic_surrender": "disabled_v1",
		"surrender_rng_allowed": false,
		"winner_selection_rng_allowed": false,
	}


func _result(
	finished: bool,
	outcome: String,
	winner_team_id: String,
	loser_team_id: String,
	team_ids: Array[String],
	eliminated_team_ids: Array[String]
) -> Dictionary:
	return {
		"status": "resolved",
		"errors": [],
		"combat_finished": finished,
		"outcome": outcome,
		"winner_team_id": winner_team_id,
		"loser_team_id": loser_team_id,
		"team_ids": team_ids.duplicate(),
		"eliminated_team_ids": eliminated_team_ids.duplicate(),
		"surrender_resolved": true,
		"surrender_occurred": false,
	}


func _invalid(errors: Array[String]) -> Dictionary:
	return {
		"status": "invalid",
		"errors": errors.duplicate(),
		"combat_finished": false,
		"outcome": "invalid",
		"winner_team_id": "",
		"loser_team_id": "",
		"team_ids": [],
		"eliminated_team_ids": [],
		"surrender_resolved": false,
		"surrender_occurred": false,
	}
