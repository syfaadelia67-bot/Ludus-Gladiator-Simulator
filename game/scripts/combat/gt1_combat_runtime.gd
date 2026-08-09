extends RefCounted

const Combat1v1LoopScript = preload("res://scripts/combat/combat_1v1_loop.gd")
const Combat2v2LoopScript = preload("res://scripts/combat/combat_2v2_loop.gd")
const CombatCarryoverResolverScript = preload("res://scripts/combat/combat_carryover_resolver.gd")
const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")

const GT1_MONTHS := [13, 16, 20]
const BOUTS_PER_ENCOUNTER := 3

var _combat_contract = CombatContractScript.new()
var _carryover = CombatCarryoverResolverScript.new()
var _loop_1v1 = Combat1v1LoopScript.new()
var _loop_2v2 = Combat2v2LoopScript.new()


func start_encounter(month: int, player_team_id: String, bout_states: Array) -> Dictionary:
	var errors := _validate_start(month, player_team_id, bout_states)
	if not errors.is_empty():
		return _rejected("invalid_gt1_encounter", errors, month, player_team_id)

	var encounter := TournamentManager.get_gt1_encounter(month)
	var templates: Array = []
	for raw_state in bout_states:
		templates.append((raw_state as Dictionary).duplicate(true))

	var first_loop := _start_loop(templates[0] as Dictionary)
	if first_loop.get("status") != "running":
		return _rejected(
			"combat_loop_start_failed",
			first_loop.get("errors", []) as Array,
			month,
			player_team_id,
		)

	return {
		"status": "combat_running",
		"errors": [],
		"month": month,
		"encounter": int(encounter.get("encounter", 0)),
		"format": str(encounter.get("format", "")),
		"player_team_id": player_team_id,
		"bout_index": 0,
		"completed_bouts": 0,
		"player_wins": 0,
		"player_points": 0,
		"substitution_used": _substitution_used(templates, player_team_id),
		"bout_templates": templates.duplicate(true),
		"active_loop": first_loop.duplicate(true),
		"last_combat_result": {},
		"last_tournament_result": {},
		"carried_fighter_ids": [],
	}


func advance_exchange(session: Dictionary, intents: Array) -> Dictionary:
	var errors := _validate_session(session)
	if not errors.is_empty():
		return _rejected(
			"invalid_gt1_session",
			errors,
			int(session.get("month", 0)),
			str(session.get("player_team_id", "")),
		)

	var active_loop := session.get("active_loop", {}) as Dictionary
	var format := str(session.get("format", ""))
	var combat_result: Dictionary
	if format == "1v1":
		combat_result = _loop_1v1.advance(active_loop, intents)
	elif format == "2v2":
		combat_result = _loop_2v2.advance(active_loop, intents)
	else:
		return _rejected(
			"unsupported_gt1_format",
			["GT I runtime supports only 1v1 and 2v2 encounters"],
			int(session.get("month", 0)),
			str(session.get("player_team_id", "")),
		)

	if combat_result.get("status") == "rejected":
		return _rejected(
			str(combat_result.get("reason", "combat_advance_failed")),
			combat_result.get("errors", []) as Array,
			int(session.get("month", 0)),
			str(session.get("player_team_id", "")),
		)

	var next := session.duplicate(true)
	next["active_loop"] = combat_result.duplicate(true)
	next["last_combat_result"] = combat_result.duplicate(true)
	if combat_result.get("status") != "combat_finished":
		next["status"] = "combat_running"
		return next

	return _complete_bout(next, combat_result)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"tournament_id": "grand_tournament_rome",
		"encounter_months": GT1_MONTHS.duplicate(),
		"bouts_per_encounter": BOUTS_PER_ENCOUNTER,
		"month_13":
		{
			"format": "1v1",
			"consecutive": true,
			"player_roster": "same_gladiator_all_three_bouts",
			"carryover": ["current_pv", "stamina"],
		},
		"month_16":
		{
			"format": "1v1",
			"consecutive": false,
			"player_roster": "independent_per_bout",
			"carryover": [],
		},
		"month_20":
		{
			"format": "2v2",
			"consecutive": true,
			"player_roster": "same_pair_with_at_most_one_unilateral_substitution",
			"carryover": ["current_pv", "stamina"],
		},
		"combat_result_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"points_per_win": 3,
		"double_ko_counts_as_win": false,
		"rival_score_generation": "not_runtime_authority",
	}


func _complete_bout(session: Dictionary, combat_result: Dictionary) -> Dictionary:
	var month := int(session.get("month", 0))
	var player_team_id := str(session.get("player_team_id", ""))
	var player_won := (
		str(combat_result.get("outcome", "")) == "team_win"
		and str(combat_result.get("winner_team_id", "")) == player_team_id
	)
	var tournament_result := TournamentManager.register_grand_tournament_fight_result(
		player_won, month
	)
	if tournament_result.is_empty():
		return _rejected(
			"gt1_result_registration_failed",
			["TournamentManager rejected the completed GT I bout result"],
			month,
			player_team_id,
		)

	var next := session.duplicate(true)
	var completed := int(session.get("completed_bouts", 0)) + 1
	next["completed_bouts"] = completed
	next["player_wins"] = int(session.get("player_wins", 0)) + (1 if player_won else 0)
	next["player_points"] = (
		int(session.get("player_points", 0)) + int(tournament_result.get("points_gained", 0))
	)
	next["last_tournament_result"] = tournament_result.duplicate(true)
	next["last_combat_result"] = combat_result.duplicate(true)

	if completed >= BOUTS_PER_ENCOUNTER:
		next["status"] = "encounter_finished"
		next["active_loop"] = {}
		next["bout_index"] = BOUTS_PER_ENCOUNTER
		next["carried_fighter_ids"] = []
		return next

	var next_index := completed
	var templates := session.get("bout_templates", []) as Array
	var next_state := (templates[next_index] as Dictionary).duplicate(true)
	var carried_ids: Array = []
	if month in [13, 20]:
		var previous_state := combat_result.get("state", {}) as Dictionary
		var carry_result: Dictionary = _carryover.prepare_consecutive_fight(
			previous_state, next_state
		)
		if carry_result.get("status") != "ready":
			return _rejected(
				"gt1_carryover_failed",
				carry_result.get("errors", []) as Array,
				month,
				player_team_id,
			)
		next_state = (carry_result.get("state", {}) as Dictionary).duplicate(true)
		carried_ids = (carry_result.get("carried_fighter_ids", []) as Array).duplicate()

	var next_loop := _start_loop(next_state)
	if next_loop.get("status") != "running":
		return _rejected(
			"combat_loop_start_failed",
			next_loop.get("errors", []) as Array,
			month,
			player_team_id,
		)
	next["status"] = "combat_running"
	next["bout_index"] = next_index
	next["active_loop"] = next_loop.duplicate(true)
	next["carried_fighter_ids"] = carried_ids.duplicate()
	return next


func _validate_start(month: int, player_team_id: String, bout_states: Array) -> Array[String]:
	var errors: Array[String] = []
	if not GT1_MONTHS.has(month):
		errors.append("GT I combat runtime requires month 13, 16 or 20")
	if player_team_id.is_empty():
		errors.append("GT I combat runtime requires player_team_id")
	if bout_states.size() != BOUTS_PER_ENCOUNTER:
		errors.append("GT I encounter requires exactly three bout CombatStates")
	if not errors.is_empty():
		return errors

	var encounter := TournamentManager.get_gt1_encounter(month)
	if encounter.is_empty():
		errors.append("TournamentManager has no GT I encounter for month %d" % month)
		return errors
	var progress := TournamentManager.get_gt1_summary().get("encounter_progress", {}) as Dictionary
	if int(progress.get(str(month), 0)) != 0:
		errors.append("GT I encounter already has registered bouts; runtime restore is required")

	var expected_format := str(encounter.get("format", ""))
	var expected_team_size := int(encounter.get("team_size", 0))
	for index in range(bout_states.size()):
		if not bout_states[index] is Dictionary:
			errors.append("GT I bout %d state must be a Dictionary" % [index + 1])
			continue
		var state := bout_states[index] as Dictionary
		errors.append_array(_combat_contract.validate_state(state))
		if str(state.get("format", "")) != expected_format:
			errors.append("GT I bout %d must use format %s" % [index + 1, expected_format])
		var player_ids := _team_fighter_ids(state, player_team_id)
		if player_ids.size() != expected_team_size:
			errors.append(
				(
					"GT I bout %d player team must contain %d fighters"
					% [index + 1, expected_team_size]
				)
			)

	if not errors.is_empty():
		return errors
	if month == 13:
		_validate_month_13_roster(bout_states, player_team_id, errors)
	elif month == 20:
		_validate_month_20_roster(bout_states, player_team_id, errors)
	return errors


func _validate_month_13_roster(
	bout_states: Array, player_team_id: String, errors: Array[String]
) -> void:
	var baseline := _team_fighter_ids(bout_states[0] as Dictionary, player_team_id)
	for index in range(1, bout_states.size()):
		if _team_fighter_ids(bout_states[index] as Dictionary, player_team_id) != baseline:
			errors.append("GT I month XIII requires the same player gladiator in all three bouts")
			return


func _validate_month_20_roster(
	bout_states: Array, player_team_id: String, errors: Array[String]
) -> void:
	var previous := _team_fighter_ids(bout_states[0] as Dictionary, player_team_id)
	var changes := 0
	for index in range(1, bout_states.size()):
		var current := _team_fighter_ids(bout_states[index] as Dictionary, player_team_id)
		if current == previous:
			continue
		var shared := 0
		for fighter_id in previous:
			if current.has(fighter_id):
				shared += 1
		if shared != 1:
			errors.append("GT I month XX substitution must replace exactly one player fighter")
			return
		changes += 1
		previous = current
	if changes > 1:
		errors.append("GT I month XX allows at most one unilateral player substitution")


func _substitution_used(bout_states: Array, player_team_id: String) -> bool:
	if bout_states.is_empty():
		return false
	var previous := _team_fighter_ids(bout_states[0] as Dictionary, player_team_id)
	for index in range(1, bout_states.size()):
		var current := _team_fighter_ids(bout_states[index] as Dictionary, player_team_id)
		if current != previous:
			return true
		previous = current
	return false


func _team_fighter_ids(state: Dictionary, team_id: String) -> Array[String]:
	var ids: Array[String] = []
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("team", "")) == team_id:
			ids.append(str(fighter.get("id", "")))
	ids.sort()
	return ids


func _start_loop(state: Dictionary) -> Dictionary:
	var format := str(state.get("format", ""))
	if format == "1v1":
		return _loop_1v1.start(state)
	if format == "2v2":
		return _loop_2v2.start(state)
	return {"status": "rejected", "errors": ["Unsupported GT I combat format: %s" % format]}


func _validate_session(session: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(session.get("status", "")) != "combat_running":
		errors.append("GT I session must be combat_running before advance")
	if not GT1_MONTHS.has(int(session.get("month", 0))):
		errors.append("GT I session has invalid encounter month")
	if str(session.get("player_team_id", "")).is_empty():
		errors.append("GT I session is missing player_team_id")
	if not session.get("active_loop", {}) is Dictionary:
		errors.append("GT I session is missing active combat loop")
	return errors


func _rejected(reason: String, errors: Array, month: int, player_team_id: String) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"month": month,
		"player_team_id": player_team_id,
		"bout_index": 0,
		"completed_bouts": 0,
		"player_wins": 0,
		"player_points": 0,
		"substitution_used": false,
		"bout_templates": [],
		"active_loop": {},
		"last_combat_result": {},
		"last_tournament_result": {},
		"carried_fighter_ids": [],
	}
