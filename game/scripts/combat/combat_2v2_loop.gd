extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatExchangeCoordinatorScript = preload(
	"res://scripts/combat/combat_exchange_coordinator.gd"
)

var _combat_contract = CombatContractScript.new()
var _coordinator = CombatExchangeCoordinatorScript.new()


func start(state: Dictionary) -> Dictionary:
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected("invalid_state", state_errors, state, 0)
	if str(state.get("format", "")) != "2v2":
		return _rejected("unsupported_format", ["Combat2v2Loop requires format 2v2"], state, 0)
	return {
		"status": "running",
		"errors": [],
		"exchange_index": 0,
		"state": state.duplicate(true),
		"last_exchange_result": {},
		"combat_end_result": {},
		"ko_fighter_ids": [],
		"combat_end_resolved": false,
		"outcome": "ongoing",
		"winner_team_id": "",
		"loser_team_id": "",
	}


func advance(loop_state: Dictionary, intents: Array) -> Dictionary:
	var loop_errors: Array[String] = _validate_loop_state(loop_state)
	if not loop_errors.is_empty():
		return _rejected(
			"invalid_loop_state",
			loop_errors,
			loop_state.get("state", {}) as Dictionary,
			int(loop_state.get("exchange_index", 0)),
		)

	var state := (loop_state.get("state", {}) as Dictionary).duplicate(true)
	var session: Dictionary = _coordinator.start_exchange(state)
	if session.get("status") != "collecting":
		return _rejected(
			"exchange_start_failed",
			session.get("errors", []) as Array,
			state,
			int(loop_state.get("exchange_index", 0)),
		)

	for raw_intent in intents:
		if not raw_intent is Dictionary:
			return _rejected(
				"invalid_intent_payload",
				["Every exchange intent must be a Dictionary"],
				state,
				int(loop_state.get("exchange_index", 0)),
			)
		session = _coordinator.submit_intent(session, raw_intent as Dictionary)
		if session.get("status") == "rejected":
			return _rejected(
				str(session.get("reason", "exchange_coordination_failed")),
				session.get("errors", []) as Array,
				state,
				int(loop_state.get("exchange_index", 0)),
			)

	if session.get("status") != "resolved":
		return _rejected(
			"incomplete_exchange",
			["2v2 loop requires exactly one valid intent from each active fighter"],
			state,
			int(loop_state.get("exchange_index", 0)),
		)

	var exchange_result := session.get("exchange_result", {}) as Dictionary
	var next_state := (exchange_result.get("state", {}) as Dictionary).duplicate(true)
	var next_exchange_index := int(loop_state.get("exchange_index", 0)) + 1
	var ko_ids := exchange_result.get("ko_fighter_ids", []) as Array
	var combat_end_result := exchange_result.get("combat_end_result", {}) as Dictionary
	var combat_finished := bool(exchange_result.get("combat_end_resolved", false))
	return {
		"status": "combat_finished" if combat_finished else "running",
		"errors": [],
		"exchange_index": next_exchange_index,
		"state": next_state,
		"last_exchange_result": exchange_result.duplicate(true),
		"combat_end_result": combat_end_result.duplicate(true),
		"ko_fighter_ids": ko_ids.duplicate(),
		"combat_end_resolved": combat_finished,
		"outcome": str(exchange_result.get("outcome", "ongoing")),
		"winner_team_id": str(exchange_result.get("winner_team_id", "")),
		"loser_team_id": str(exchange_result.get("loser_team_id", "")),
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"format": "2v2",
		"state_progression": "resolved_exchange_state_becomes_next_exchange_state",
		"intent_collection": "exactly_one_intent_per_active_fighter",
		"combat_end_authority": "combat_simulator",
		"finish_condition": "team_elimination",
		"winner_authority": "combat_simulator",
		"automatic_surrender": "disabled_v1",
		"partial_team_ko": "combat_continues_while_team_has_active_fighter",
		"cross_team_simultaneous_ko": "commit_both_then_continue_if_each_team_survives",
		"full_simultaneous_elimination": "double_ko",
		"carryover_scope": "within_same_combat_via_resolved_state",
		"between_consecutive_gt_fights": "combat_carryover_resolver",
	}


func _validate_loop_state(loop_state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(loop_state.get("status", "")) != "running":
		errors.append("2v2 loop must be running before advance")
	if not loop_state.get("state", {}) is Dictionary:
		errors.append("2v2 loop state must contain a CombatState Dictionary")
	if not errors.is_empty():
		return errors
	var state := loop_state.get("state", {}) as Dictionary
	errors.append_array(_combat_contract.validate_state(state))
	if str(state.get("format", "")) != "2v2":
		errors.append("2v2 loop state format must remain 2v2")
	return errors


func _rejected(reason: String, errors: Array, state: Dictionary, exchange_index: int) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"exchange_index": exchange_index,
		"state": state.duplicate(true),
		"last_exchange_result": {},
		"combat_end_result": {},
		"ko_fighter_ids": [],
		"combat_end_resolved": false,
		"outcome": "invalid",
		"winner_team_id": "",
		"loser_team_id": "",
	}
