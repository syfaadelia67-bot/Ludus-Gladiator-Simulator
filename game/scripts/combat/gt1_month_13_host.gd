extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")

const MONTH := 13
const BOUT_COUNT := 3

var _combat_contract = CombatContractScript.new()
var _runtime = GT1CombatRuntimeScript.new()


func prepare_request(
	player_gladiator_id: String, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	var errors: Array[String] = []
	if player_gladiator_id.is_empty():
		errors.append("GT I month XIII requires one explicit player gladiator id")
	if player_team_id.is_empty():
		errors.append("GT I month XIII requires player_team_id")
	if opponent_fighters.size() != BOUT_COUNT:
		errors.append("GT I month XIII requires exactly three explicit rival gladiator snapshots")

	var opponent_fighters_by_bout: Array = []
	for index in range(opponent_fighters.size()):
		var raw_opponent: Variant = opponent_fighters[index]
		if not raw_opponent is Dictionary:
			errors.append("GT I month XIII rival %d must be a Combat V1 Dictionary" % [index + 1])
			continue
		var opponent := raw_opponent as Dictionary
		if _looks_like_beast(opponent):
			errors.append("GT I month XIII does not allow beasts")
			continue
		var snapshot_errors: Array[String] = _combat_contract.validate_fighter_snapshot(opponent)
		for snapshot_error in snapshot_errors:
			errors.append("GT I month XIII rival %d: %s" % [index + 1, snapshot_error])
		if str(opponent.get("team", "")) == player_team_id:
			errors.append("GT I month XIII rival fighters must use a rival team id")
		opponent_fighters_by_bout.append([opponent.duplicate(true)])

	if not errors.is_empty():
		return _rejected(errors)

	var player_ids_by_bout: Array = []
	for _bout in range(BOUT_COUNT):
		player_ids_by_bout.append([player_gladiator_id])
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"month": MONTH,
		"format": "1v1",
		"player_team_id": player_team_id,
		"player_gladiator_id": player_gladiator_id,
		"player_ids_by_bout": player_ids_by_bout,
		"opponent_fighters_by_bout": opponent_fighters_by_bout,
		"consecutive": true,
		"carryover": ["current_pv", "stamina"],
		"beasts_allowed": false,
		"points_per_win": 3,
		"max_points": 9,
	}


func start(
	player_gladiator_id: String, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	var request := prepare_request(player_gladiator_id, player_team_id, opponent_fighters)
	if request.get("status") != "ready":
		return request
	return _runtime.start_encounter_from_live_roster(
		MONTH,
		player_team_id,
		request.get("player_ids_by_bout", []) as Array,
		request.get("opponent_fighters_by_bout", []) as Array,
	)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"month": MONTH,
		"format": "1v1",
		"bouts": BOUT_COUNT,
		"player_selection": "one_explicit_gladiator_reused_all_three_bouts",
		"opponent_selection": "three_explicit_combat_v1_gladiator_snapshots",
		"beasts_allowed": false,
		"consecutive": true,
		"carryover": ["current_pv", "stamina"],
		"points_per_win": 3,
		"max_points": 9,
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"rival_generation_allowed": false,
		"save_version_change_required": false,
	}


func _looks_like_beast(fighter: Dictionary) -> bool:
	if fighter.has("beast_id") or fighter.has("species_id"):
		return true
	return str(fighter.get("entity_type", fighter.get("kind", ""))).to_lower() == "beast"


func _rejected(errors: Array[String]) -> Dictionary:
	return {
		"status": "rejected",
		"reason": "invalid_gt1_month_13_request",
		"errors": errors.duplicate(),
		"month": MONTH,
		"format": "1v1",
		"player_ids_by_bout": [],
		"opponent_fighters_by_bout": [],
		"beasts_allowed": false,
	}
