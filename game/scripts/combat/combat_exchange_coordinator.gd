extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")
const CombatRuntimeStateBuilderScript = preload("res://scripts/combat/combat_runtime_state_builder.gd")
const CombatSimulatorScript = preload("res://scripts/combat/combat_simulator.gd")

var _combat_contract = CombatContractScript.new()
var _policy_contract = CombatPolicyContractScript.new()
var _runtime_builder = CombatRuntimeStateBuilderScript.new()
var _simulator = CombatSimulatorScript.new()


func start_exchange(state: Dictionary) -> Dictionary:
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected("invalid_state", state_errors, state, {})
	return {
		"status": "collecting",
		"errors": [],
		"state": state.duplicate(true),
		"intents_by_actor": {},
		"required_actor_ids": _required_actor_ids(state),
		"missing_actor_ids": _required_actor_ids(state),
		"exchange_result": {},
	}


func submit_intent(session: Dictionary, desired_action: Dictionary) -> Dictionary:
	var session_errors: Array[String] = _validate_session(session)
	if not session_errors.is_empty():
		return _rejected(
			"invalid_session",
			session_errors,
			session.get("state", {}) as Dictionary,
			session.get("intents_by_actor", {}) as Dictionary,
		)

	var state := (session.get("state", {}) as Dictionary).duplicate(true)
	var actor_id := str(desired_action.get("actor_id", ""))
	var required_actor_ids: Array[String] = _required_actor_ids(state)
	if not required_actor_ids.has(actor_id):
		return _rejected(
			"inactive_actor_intent",
			["Fighter %s is not active for this exchange" % actor_id],
			state,
			session.get("intents_by_actor", {}) as Dictionary,
		)

	var policy_errors: Array[String] = _policy_contract.validate_desired_action(
		state, desired_action
	)
	if not policy_errors.is_empty():
		return _rejected(
			"invalid_desired_action",
			policy_errors,
			state,
			session.get("intents_by_actor", {}) as Dictionary,
		)

	var intents := (session.get("intents_by_actor", {}) as Dictionary).duplicate(true)
	if intents.has(actor_id):
		return _rejected(
			"duplicate_actor_intent",
			["Fighter %s already submitted an intent for this exchange" % actor_id],
			state,
			intents,
		)
	intents[actor_id] = desired_action.duplicate(true)

	var missing_actor_ids: Array[String] = []
	for required_actor_id in required_actor_ids:
		if not intents.has(required_actor_id):
			missing_actor_ids.append(required_actor_id)

	if not missing_actor_ids.is_empty():
		return {
			"status": "collecting",
			"errors": [],
			"state": state.duplicate(true),
			"intents_by_actor": intents.duplicate(true),
			"required_actor_ids": required_actor_ids.duplicate(),
			"missing_actor_ids": missing_actor_ids.duplicate(),
			"exchange_result": {},
		}

	var ordered_intents: Array = []
	for required_actor_id in required_actor_ids:
		ordered_intents.append((intents[required_actor_id] as Dictionary).duplicate(true))
	var exchange_result: Dictionary = _simulator.resolve_exchange(state, ordered_intents)
	if exchange_result.get("status") != "resolved":
		return {
			"status": "rejected",
			"reason": "exchange_resolution_failed",
			"errors": (exchange_result.get("errors", []) as Array).duplicate(),
			"state": state.duplicate(true),
			"intents_by_actor": intents.duplicate(true),
			"required_actor_ids": required_actor_ids.duplicate(),
			"missing_actor_ids": [],
			"exchange_result": exchange_result.duplicate(true),
		}

	return {
		"status": "resolved",
		"errors": [],
		"state": state.duplicate(true),
		"intents_by_actor": intents.duplicate(true),
		"required_actor_ids": required_actor_ids.duplicate(),
		"missing_actor_ids": [],
		"exchange_result": exchange_result.duplicate(true),
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"authority": "combat_simulator",
		"collection_mode": "exactly_one_intent_per_active_fighter",
		"knocked_out_fighter_intent": "reject",
		"duplicate_actor_intent": "reject",
		"missing_actor_intent": "collecting",
		"default_action_allowed": false,
		"tactical_selection_allowed": false,
		"serialization_order": "actor_id_ascending",
		"serialization_order_is_priority": false,
	}


func _required_actor_ids(state: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if _runtime_builder.is_knocked_out(fighter):
			continue
		ids.append(str(fighter.get("id", "")))
	ids.sort()
	return ids


func _validate_session(session: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(session.get("status", "")) != "collecting":
		errors.append("Exchange session must be collecting")
	if not session.get("state", {}) is Dictionary:
		errors.append("Exchange session state must be a Dictionary")
	if not session.get("intents_by_actor", {}) is Dictionary:
		errors.append("Exchange session intents_by_actor must be a Dictionary")
	if not errors.is_empty():
		return errors
	var state := session.get("state", {}) as Dictionary
	errors.append_array(_combat_contract.validate_state(state))
	return errors


func _rejected(
	reason: String, errors: Array, state: Dictionary, intents_by_actor: Dictionary
) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"state": state.duplicate(true),
		"intents_by_actor": intents_by_actor.duplicate(true),
		"required_actor_ids": [],
		"missing_actor_ids": [],
		"exchange_result": {},
	}
