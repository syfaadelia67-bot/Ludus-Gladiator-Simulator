extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")
const GT1RosterSelectionContractScript = preload(
	"res://scripts/combat/gt1_roster_selection_contract.gd"
)

const MONTH := 20
const BOUT_COUNT := 3
const TEAM_SIZE := 2

var _combat_contract = CombatContractScript.new()
var _runtime = GT1CombatRuntimeScript.new()
var _selection_contract = GT1RosterSelectionContractScript.new()


func prepare_request(
	player_ids_by_bout: Array, player_team_id: String, opponent_fighters_by_bout: Array
) -> Dictionary:
	var errors: Array[String] = []
	if player_team_id.is_empty():
		errors.append("GT I month XX requires player_team_id")
	if player_ids_by_bout.size() != BOUT_COUNT:
		errors.append("GT I month XX requires exactly three player pair selections")
	if opponent_fighters_by_bout.size() != BOUT_COUNT:
		errors.append("GT I month XX requires exactly three explicit rival pairs")

	var normalized_player_ids := _normalize_player_selections(player_ids_by_bout, errors)
	var available_selected_ids := _unique_player_ids(normalized_player_ids)
	if normalized_player_ids.size() == BOUT_COUNT:
		errors.append_array(
			_selection_contract.validate_selection(
				MONTH, normalized_player_ids, available_selected_ids
			)
		)

	var normalized_opponents := _normalize_opponents(
		opponent_fighters_by_bout, player_team_id, errors
	)
	if not errors.is_empty():
		return _rejected(errors)

	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"month": MONTH,
		"format": "2v2",
		"player_team_id": player_team_id,
		"player_ids_by_bout": normalized_player_ids.duplicate(true),
		"opponent_fighters_by_bout": normalized_opponents.duplicate(true),
		"consecutive": true,
		"carryover": ["current_pv", "stamina"],
		"substitution_used": _substitution_used(normalized_player_ids),
		"substitution_limit": 1,
		"points_per_win": 3,
		"max_points": 9,
	}


func start(
	player_ids_by_bout: Array, player_team_id: String, opponent_fighters_by_bout: Array
) -> Dictionary:
	var request := prepare_request(player_ids_by_bout, player_team_id, opponent_fighters_by_bout)
	if request.get("status") != "ready":
		return request
	return (
		_runtime
		. start_encounter_from_live_roster(
			MONTH,
			player_team_id,
			request.get("player_ids_by_bout", []) as Array,
			request.get("opponent_fighters_by_bout", []) as Array,
		)
	)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"month": MONTH,
		"format": "2v2",
		"bouts": BOUT_COUNT,
		"team_size": TEAM_SIZE,
		"player_selection": "explicit_pair_per_bout",
		"roster_rule": "same_pair_with_at_most_one_unilateral_substitution",
		"opponent_selection": "three_explicit_combat_v1_rival_pairs",
		"consecutive": true,
		"carryover": ["current_pv", "stamina"],
		"substitution_limit": 1,
		"substitute_enters_fresh": true,
		"continuing_fighter_carries_state": true,
		"beasts_allowed": false,
		"points_per_win": 3,
		"max_points": 9,
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"rival_generation_allowed": false,
		"save_version_change_required": false,
	}


func _normalize_player_selections(player_ids_by_bout: Array, errors: Array[String]) -> Array:
	var result: Array = []
	for index in range(player_ids_by_bout.size()):
		var raw_pair: Variant = player_ids_by_bout[index]
		if not raw_pair is Array:
			errors.append("GT I month XX player bout %d selection must be an Array" % [index + 1])
			continue
		var pair: Array[String] = []
		for raw_id in raw_pair as Array:
			var fighter_id := str(raw_id)
			if fighter_id.is_empty():
				errors.append("GT I month XX player bout %d contains an empty id" % [index + 1])
				continue
			if pair.has(fighter_id):
				errors.append(
					"GT I month XX player bout %d cannot duplicate a gladiator" % [index + 1]
				)
				continue
			pair.append(fighter_id)
		pair.sort()
		if pair.size() != TEAM_SIZE:
			errors.append(
				"GT I month XX player bout %d requires exactly two gladiators" % [index + 1]
			)
		result.append(pair)
	return result


func _normalize_opponents(
	opponent_fighters_by_bout: Array, player_team_id: String, errors: Array[String]
) -> Array:
	var result: Array = []
	for index in range(opponent_fighters_by_bout.size()):
		var raw_pair: Variant = opponent_fighters_by_bout[index]
		if not raw_pair is Array:
			errors.append("GT I month XX rival bout %d selection must be an Array" % [index + 1])
			continue
		var pair := raw_pair as Array
		if pair.size() != TEAM_SIZE:
			errors.append("GT I month XX rival bout %d requires exactly two fighters" % [index + 1])
			continue
		var normalized_pair: Array = []
		var rival_team_id := ""
		var seen_ids: Array[String] = []
		for raw_opponent in pair:
			if not raw_opponent is Dictionary:
				errors.append("GT I month XX rival fighters must be Combat V1 Dictionaries")
				continue
			var opponent := raw_opponent as Dictionary
			if _looks_like_beast(opponent):
				errors.append("GT I month XX does not allow beasts")
				continue
			var snapshot_errors: Array[String] = _combat_contract.validate_fighter_snapshot(
				opponent
			)
			for snapshot_error in snapshot_errors:
				errors.append("GT I month XX rival bout %d: %s" % [index + 1, snapshot_error])
			var fighter_id := str(opponent.get("id", ""))
			if seen_ids.has(fighter_id):
				errors.append(
					"GT I month XX rival bout %d cannot duplicate a fighter" % [index + 1]
				)
			seen_ids.append(fighter_id)
			var team_id := str(opponent.get("team", ""))
			if team_id == player_team_id:
				errors.append("GT I month XX rival fighters must use a rival team id")
			if rival_team_id.is_empty():
				rival_team_id = team_id
			elif team_id != rival_team_id:
				errors.append("GT I month XX rival pair must belong to one rival team")
			normalized_pair.append(opponent.duplicate(true))
		result.append(normalized_pair)
	return result


func _unique_player_ids(player_ids_by_bout: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_pair in player_ids_by_bout:
		if not raw_pair is Array:
			continue
		for raw_id in raw_pair as Array:
			var fighter_id := str(raw_id)
			if not fighter_id.is_empty() and not result.has(fighter_id):
				result.append(fighter_id)
	result.sort()
	return result


func _substitution_used(player_ids_by_bout: Array) -> bool:
	if player_ids_by_bout.is_empty():
		return false
	var previous := (player_ids_by_bout[0] as Array).duplicate()
	previous.sort()
	for index in range(1, player_ids_by_bout.size()):
		var current := (player_ids_by_bout[index] as Array).duplicate()
		current.sort()
		if current != previous:
			return true
		previous = current
	return false


func _looks_like_beast(fighter: Dictionary) -> bool:
	if fighter.has("beast_id") or fighter.has("species_id"):
		return true
	return str(fighter.get("entity_type", fighter.get("kind", ""))).to_lower() == "beast"


func _rejected(errors: Array[String]) -> Dictionary:
	return {
		"status": "rejected",
		"reason": "invalid_gt1_month_20_request",
		"errors": errors.duplicate(),
		"month": MONTH,
		"format": "2v2",
		"player_ids_by_bout": [],
		"opponent_fighters_by_bout": [],
		"consecutive": true,
		"carryover": ["current_pv", "stamina"],
		"substitution_used": false,
		"substitution_limit": 1,
		"beasts_allowed": false,
	}
