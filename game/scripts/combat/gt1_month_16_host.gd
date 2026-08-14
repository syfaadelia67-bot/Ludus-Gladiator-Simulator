extends RefCounted

const CombatBeastFighterAdapterScript = preload(
	"res://scripts/combat/combat_beast_fighter_adapter.gd"
)
const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")
const GT1RosterSelectionContractScript = preload(
	"res://scripts/combat/gt1_roster_selection_contract.gd"
)

const MONTH := 16
const BOUT_COUNT := 3

var _beast_adapter = CombatBeastFighterAdapterScript.new()
var _combat_contract = CombatContractScript.new()
var _runtime = GT1CombatRuntimeScript.new()
var _selection_contract = GT1RosterSelectionContractScript.new()


func prepare_human_request(
	player_gladiator_ids: Array, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	return _prepare_request(
		player_gladiator_ids,
		player_team_id,
		opponent_fighters,
		false,
	)


func prepare_beast_request(
	player_gladiator_ids: Array, player_team_id: String, beast_ids: Array, opponent_team_id: String
) -> Dictionary:
	var beast_readiness := get_beast_readiness()
	var errors := _validate_player_request(player_gladiator_ids, player_team_id)
	if beast_ids.size() != BOUT_COUNT:
		errors.append("GT I month XVI requires exactly three canonical beast ids")
	if opponent_team_id.is_empty():
		errors.append("GT I month XVI beast request requires opponent_team_id")
	elif opponent_team_id == player_team_id:
		errors.append("GT I month XVI beast team must differ from player_team_id")
	if beast_readiness.get("beast_selection_ready") != true:
		errors.append("GT I month XVI beast adapter is not ready")
	if not errors.is_empty():
		return _rejected(errors, beast_readiness)

	var opponent_fighters: Array = []
	for index in range(beast_ids.size()):
		var beast_id := str(beast_ids[index])
		var fighter_id := "gt1_m16_beast_%d_%s" % [index + 1, beast_id]
		var adapted: Dictionary = _beast_adapter.build_from_beast_id(
			beast_id, fighter_id, opponent_team_id
		)
		if adapted.get("status") != "ready":
			for raw_error in adapted.get("errors", []) as Array:
				errors.append("GT I month XVI beast %d: %s" % [index + 1, str(raw_error)])
			continue
		opponent_fighters.append((adapted.get("fighter", {}) as Dictionary).duplicate(true))
	if not errors.is_empty():
		return _rejected(errors, beast_readiness)
	return _prepare_request(
		player_gladiator_ids,
		player_team_id,
		opponent_fighters,
		true,
	)


func start_human(
	player_gladiator_ids: Array, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	var request := prepare_human_request(player_gladiator_ids, player_team_id, opponent_fighters)
	return _start_request(request)


func start_beasts(
	player_gladiator_ids: Array, player_team_id: String, beast_ids: Array, opponent_team_id: String
) -> Dictionary:
	var request := prepare_beast_request(
		player_gladiator_ids, player_team_id, beast_ids, opponent_team_id
	)
	return _start_request(request)


func get_beast_readiness() -> Dictionary:
	var adapter_audit := _beast_adapter.audit_catalog(DataRepository.beasts)
	return _selection_contract.get_month_16_beast_readiness(
		DataRepository.beasts, adapter_audit.get("ready") == true
	)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"month": MONTH,
		"format": "1v1",
		"bouts": BOUT_COUNT,
		"player_human_selection": "one_explicit_available_gladiator_per_independent_bout",
		"human_opponent_selection": "three_explicit_non_beast_combat_v1_snapshots",
		"beast_opponent_selection": "three_canonical_beast_ids_via_combat_beast_fighter_adapter",
		"independent_bouts": true,
		"carryover": [],
		"beasts_allowed_by_design": true,
		"beast_selection_boundary": "gt1_beast_readiness_contract",
		"beast_selection_current_behavior": "canonical_beast_adapter_ready",
		"human_selection_remains_available": true,
		"manual_beast_snapshot_allowed": false,
		"invent_beast_stats_allowed": false,
		"points_per_win": 3,
		"max_points": 9,
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"rival_generation_allowed": false,
		"save_version_change_required": false,
	}


func _prepare_request(
	player_gladiator_ids: Array,
	player_team_id: String,
	opponent_fighters: Array,
	allow_canonical_beasts: bool
) -> Dictionary:
	var errors := _validate_player_request(player_gladiator_ids, player_team_id)
	if opponent_fighters.size() != BOUT_COUNT:
		errors.append("GT I month XVI requires exactly three explicit opponent fighter snapshots")

	var player_ids_by_bout: Array = []
	for index in range(player_gladiator_ids.size()):
		var player_id := str(player_gladiator_ids[index])
		if player_id.is_empty():
			continue
		player_ids_by_bout.append([player_id])

	var opponent_fighters_by_bout: Array = []
	var beast_readiness := get_beast_readiness()
	for index in range(opponent_fighters.size()):
		var raw_opponent: Variant = opponent_fighters[index]
		if not raw_opponent is Dictionary:
			errors.append("GT I month XVI opponent %d must be a Combat V1 Dictionary" % [index + 1])
			continue
		var opponent := raw_opponent as Dictionary
		if _looks_like_beast(opponent) and not allow_canonical_beasts:
			(
				errors
				. append(
					"GT I month XVI manual beast snapshots are forbidden; use the canonical beast adapter"
				)
			)
			continue
		if _looks_like_beast(opponent) and beast_readiness.get("beast_selection_ready") != true:
			errors.append("GT I month XVI canonical beast adapter is not ready")
			continue
		var snapshot_errors: Array[String] = _combat_contract.validate_fighter_snapshot(opponent)
		for snapshot_error in snapshot_errors:
			errors.append("GT I month XVI opponent %d: %s" % [index + 1, snapshot_error])
		if str(opponent.get("team", "")) == player_team_id:
			errors.append("GT I month XVI opponent fighters must use a rival team id")
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


func _validate_player_request(player_gladiator_ids: Array, player_team_id: String) -> Array[String]:
	var errors: Array[String] = []
	if player_gladiator_ids.size() != BOUT_COUNT:
		errors.append("GT I month XVI requires one explicit player gladiator id per bout")
	if player_team_id.is_empty():
		errors.append("GT I month XVI requires player_team_id")
	for index in range(player_gladiator_ids.size()):
		if str(player_gladiator_ids[index]).is_empty():
			errors.append("GT I month XVI bout %d requires a player gladiator id" % [index + 1])
	return errors


func _start_request(request: Dictionary) -> Dictionary:
	if request.get("status") != "ready":
		return request
	return (
		_runtime
		. start_encounter_from_live_roster(
			MONTH,
			str(request.get("player_team_id", "")),
			request.get("player_ids_by_bout", []) as Array,
			request.get("opponent_fighters_by_bout", []) as Array,
		)
	)


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
