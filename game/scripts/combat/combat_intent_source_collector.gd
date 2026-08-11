extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")
const CombatRuntimeStateBuilderScript = preload(
	"res://scripts/combat/combat_runtime_state_builder.gd"
)
const LimboAIPolicyRunnerScript = preload("res://scripts/combat/limboai_policy_runner.gd")

var _combat_contract = CombatContractScript.new()
var _policy_contract = CombatPolicyContractScript.new()
var _runtime_builder = CombatRuntimeStateBuilderScript.new()
var _limboai_runner = LimboAIPolicyRunnerScript.new()


func set_skill_mechanics(entries: Array) -> void:
	_policy_contract.set_skill_mechanics(entries)


func collect(
	state: Dictionary,
	player_team_id: String,
	player_intents_by_actor: Dictionary,
	ai_requests_by_actor: Dictionary
) -> Dictionary:
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected("invalid_state", state_errors)
	if player_team_id.is_empty():
		return _rejected("invalid_player_team", ["Intent collection requires player_team_id"])

	var active_fighters := _active_fighters(state)
	var active_ids: Array[String] = []
	var player_ids: Array[String] = []
	var ai_ids: Array[String] = []
	for fighter in active_fighters:
		var actor_id := str(fighter.get("id", ""))
		active_ids.append(actor_id)
		if str(fighter.get("team", "")) == player_team_id:
			player_ids.append(actor_id)
		else:
			ai_ids.append(actor_id)

	var source_errors := _validate_source_keys(
		active_ids,
		player_ids,
		ai_ids,
		player_intents_by_actor,
		ai_requests_by_actor,
	)
	if not source_errors.is_empty():
		return _rejected("invalid_intent_sources", source_errors)

	var intents: Array = []
	var providers_by_actor: Dictionary = {}
	var skill_activations_by_actor: Dictionary = {}
	for fighter in active_fighters:
		var actor_result := _resolve_fighter_intent(
			state,
			fighter,
			player_team_id,
			player_intents_by_actor,
			ai_requests_by_actor,
		)
		if actor_result.get("status") != "ready":
			return _rejected(
				str(actor_result.get("reason", "intent_source_rejected")),
				_to_string_array(actor_result.get("errors", [])),
			)
		var actor_id := str(fighter.get("id", ""))
		intents.append((actor_result.get("desired_action", {}) as Dictionary).duplicate(true))
		providers_by_actor[actor_id] = str(actor_result.get("provider", ""))
		var skill_activation := actor_result.get("skill_activation", {}) as Dictionary
		if not skill_activation.is_empty():
			skill_activations_by_actor[actor_id] = skill_activation.duplicate(true)

	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"intents": intents.duplicate(true),
		"providers_by_actor": providers_by_actor.duplicate(true),
		"skill_activations_by_actor": skill_activations_by_actor.duplicate(true),
		"active_actor_ids": active_ids.duplicate(),
		"combat_authority": "combat_simulator",
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"player_source": "explicit_desired_action",
		"ai_source": "limboai_policy_runner",
		"collection_scope": "exactly_one_source_per_active_fighter",
		"inactive_or_unknown_source": "reject",
		"missing_source": "reject",
		"default_action_allowed": false,
		"skill_translation": "combat_skill_runtime_resolver",
		"combat_authority": "combat_simulator",
		"policy_may_resolve_combat": false,
	}


func _resolve_fighter_intent(
	state: Dictionary,
	fighter: Dictionary,
	player_team_id: String,
	player_intents_by_actor: Dictionary,
	ai_requests_by_actor: Dictionary
) -> Dictionary:
	var actor_id := str(fighter.get("id", ""))
	if str(fighter.get("team", "")) == player_team_id:
		return _resolve_player_intent(state, actor_id, player_intents_by_actor.get(actor_id, null))
	return _resolve_ai_intent(state, actor_id, ai_requests_by_actor.get(actor_id, null))


func _resolve_player_intent(state: Dictionary, actor_id: String, raw_intent: Variant) -> Dictionary:
	if not raw_intent is Dictionary:
		return _actor_rejected(
			"invalid_player_intent",
			["Player fighter %s requires one desired-action Dictionary" % actor_id],
		)
	var desired_action := (raw_intent as Dictionary).duplicate(true)
	var errors := _validate_actor_action(state, actor_id, desired_action)
	if not errors.is_empty():
		return _actor_rejected("invalid_player_intent", errors)
	var translated := _policy_contract.resolve_desired_action(state, desired_action)
	if translated.get("status") != "ready":
		return _actor_rejected(
			"invalid_player_skill_translation",
			_to_string_array(translated.get("errors", [])),
		)
	return _actor_ready(
		"player",
		translated.get("desired_action", {}) as Dictionary,
		translated.get("skill_activation", {}) as Dictionary,
	)


func _resolve_ai_intent(state: Dictionary, actor_id: String, raw_request: Variant) -> Dictionary:
	if not raw_request is Dictionary:
		return _actor_rejected(
			"invalid_ai_request",
			["AI fighter %s requires one LimboAI request Dictionary" % actor_id],
		)
	var ai_request := raw_request as Dictionary
	var proposal_value: Variant = ai_request.get("policy_proposal", null)
	if not proposal_value is Dictionary:
		return _actor_rejected(
			"invalid_ai_request",
			["AI fighter %s request requires policy_proposal" % actor_id],
		)
	var agent := ai_request.get("agent", null) as Node
	var instance_owner := ai_request.get("instance_owner", null) as Node
	var ai_result: Dictionary = (
		_limboai_runner
		. evaluate_proposal(
			state,
			actor_id,
			proposal_value as Dictionary,
			agent,
			instance_owner,
		)
	)
	if ai_result.get("status") != "ready":
		return _actor_rejected(
			"limboai_intent_rejected",
			_to_string_array(ai_result.get("errors", [])),
		)
	var desired_action := (ai_result.get("desired_action", {}) as Dictionary).duplicate(true)
	var errors := _validate_actor_action(state, actor_id, desired_action)
	if not errors.is_empty():
		return _actor_rejected("invalid_limboai_intent", errors)
	var translated := _policy_contract.resolve_desired_action(state, desired_action)
	if translated.get("status") != "ready":
		return _actor_rejected(
			"invalid_limboai_skill_translation",
			_to_string_array(translated.get("errors", [])),
		)
	return _actor_ready(
		"limboai",
		translated.get("desired_action", {}) as Dictionary,
		translated.get("skill_activation", {}) as Dictionary,
	)


func _actor_ready(
	provider: String, desired_action: Dictionary, skill_activation: Dictionary = {}
) -> Dictionary:
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"provider": provider,
		"desired_action": desired_action.duplicate(true),
		"skill_activation": skill_activation.duplicate(true),
	}


func _actor_rejected(reason: String, errors: Array[String]) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"provider": "",
		"desired_action": {},
		"skill_activation": {},
	}


func _active_fighters(state: Dictionary) -> Array[Dictionary]:
	var fighters: Array[Dictionary] = []
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if _runtime_builder.is_knocked_out(fighter):
			continue
		fighters.append(fighter)
	fighters.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("id", "")) < str(right.get("id", ""))
	)
	return fighters


func _validate_source_keys(
	active_ids: Array[String],
	player_ids: Array[String],
	ai_ids: Array[String],
	player_intents_by_actor: Dictionary,
	ai_requests_by_actor: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	for raw_actor_id in player_intents_by_actor.keys():
		var actor_id := str(raw_actor_id)
		if not active_ids.has(actor_id):
			errors.append(
				"Player intent source references inactive or unknown fighter %s" % actor_id
			)
		elif not player_ids.has(actor_id):
			errors.append("Player intent source references non-player fighter %s" % actor_id)
	for raw_actor_id in ai_requests_by_actor.keys():
		var actor_id := str(raw_actor_id)
		if not active_ids.has(actor_id):
			errors.append("AI intent source references inactive or unknown fighter %s" % actor_id)
		elif not ai_ids.has(actor_id):
			errors.append("AI intent source references player fighter %s" % actor_id)
	for actor_id in player_ids:
		if not player_intents_by_actor.has(actor_id):
			errors.append("Missing player intent source for active fighter %s" % actor_id)
	for actor_id in ai_ids:
		if not ai_requests_by_actor.has(actor_id):
			errors.append("Missing AI intent source for active fighter %s" % actor_id)
	return errors


func _validate_actor_action(
	state: Dictionary, expected_actor_id: String, desired_action: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	if str(desired_action.get("actor_id", "")) != expected_actor_id:
		errors.append("Intent source for %s returned a different actor_id" % expected_actor_id)
		return errors
	errors.append_array(_policy_contract.validate_desired_action(state, desired_action))
	return errors


func _rejected(reason: String, errors: Array[String]) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"intents": [],
		"providers_by_actor": {},
		"skill_activations_by_actor": {},
		"active_actor_ids": [],
		"combat_authority": "combat_simulator",
	}


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is not Array:
		return result
	for item in value as Array:
		result.append(str(item))
	return result
