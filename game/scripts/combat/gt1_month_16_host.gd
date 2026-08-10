extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")
const GT1RosterSelectionContractScript = preload(
	"res://scripts/combat/gt1_roster_selection_contract.gd"
)

const MONTH := 16
const BOUT_COUNT := 3

var _combat_contract = CombatContractScript.new()
var _runtime = GT1CombatRuntimeScript.new()
var _selection_contract = GT1RosterSelectionContractScript.new()


func prepare_human_request(
	player_gladiator_ids: Array, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	var errors: Array[String] = []
	if player_gladiator_ids.size() != BOUT_COUNT:
		errors.append("GT I month XVI requires one explicit player gladiator id per bout")
	if player_team_id.is_empty():
		errors.append("GT I month XVI requires player_team_id")
	if opponent_fighters.size() != BOUT_COUNT:
		errors.append("GT I month XVI requires exactly three explicit rival fighter snapshots")

	var player_ids_by_bout: Array = []
	for index in range(player_gladiator_ids.size()):
		var player_id := str(player_gladiator_ids[index])
		if player_id.is_empty():
			errors.append("GT I month XVI bout %d requires a player gladiator id" % [index + 1])
			continue
		player_ids_by_bout.append([player_id])

	var opponent_fighters_by_bout: Array = []
	var beast_readiness := get_beast_readiness()
	for index in range(opponent_fighters.size()):
		var raw_opponent: Variant = opponent_fighters[index]
		if not raw_opponent is Dictionary:
			errors.append("GT I month XVI rival %d must be a Combat V1 Dictionary" % [index + 1])
			continue
		var opponent := raw_opponent as Dictionary
		if _looks_like_beast(opponent) and beast_readiness.get("beast_selection_ready") != true:
			errors.append(
			"GT I month XVI beast combat is blocked until canonical stats and runtime adapter are ready"
		)
			continue
		var snapshot_errors: Array[String] = _combat_contract.validate_fighter_snapshot(opponent)
		for snapshot_error in snapshot_errors:
			errors.append("GT I month XVI rival %d: %s" % [index + 1, snapshot_error])
		if str(opponent.get("team", "")) == player_team_id:
			errors.append("GT I month XVI rival fighters must use a rival team id")
		opponent_fighters_by_bout.append([opponent.duplicate(true)])

	if not errors.is_empty():
		return _rejected(errors, beast_readiness)
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"month": MONTH,
		"format": "1v1",
		"player_team_id": player_team_id,
		"player_ids_by_bout": player_ids_by_bout,
		"opponent_fighters_by_bout": opponent_fighters_by_bout,
		"independent_bouts": true,
		"carryover": [],
		"human_selection_ready": true,
		"beasts_allowed_by_design": true,
		"beast_selection_ready": bool(beast_readiness.get("beast_selection_ready", false)),
		"beast_readiness": beast_readiness.duplicate(true),
		"points_per_win": 3,
		"max_points": 9,
	}


func start_human(
	player_gladiator_ids: Array, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	var request := prepare_human_request(player_gladiator_ids, player_team_id, opponent_fighters)
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


func get_beast_readiness() -> Dictionary:
	return _selection_contract.get_month_16_beast_readiness(DataRepository.beasts, false)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"month": MONTH,
		"format": "1v1",
		"bouts": BOUT_COUNT,
		"player_human_selection": "one_explicit_available_gladiator_per_independent_bout",
		"opponent_selection": "three_explicit_combat_v1_snapshots",
		"independent_bouts": true,
		"carryover": [],
		"beasts_allowed_by_design": true,
		"beast_selection_boundary": "gt1_beast_readiness_contract",
		"beast_selection_current_behavior": "blocked_until_canonical_stats_and_runtime_adapter",
		"human_fallback_allowed": true,
		"invent_beast_stats_allowed": false,
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


func _rejected(errors: Array[String], beast_readiness: Dictionary) -> Dictionary:
	return {
		"status": "rejected",
		"reason": "invalid_gt1_month_16_request",
		"errors": errors.duplicate(),
		"month": MONTH,
		"format": "1v1",
		"player_ids_by_bout": [],
		"opponent_fighters_by_bout": [],
		"independent_bouts": true,
		"carryover": [],
		"human_selection_ready": true,
		"beasts_allowed_by_design": true,
		"beast_selection_ready": bool(beast_readiness.get("beast_selection_ready", false)),
		"beast_readiness": beast_readiness.duplicate(true),
	}
