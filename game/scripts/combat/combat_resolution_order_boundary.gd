extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")
const CombatRuntimeStateBuilderScript = preload(
	"res://scripts/combat/combat_runtime_state_builder.gd"
)

const PHASE_ORDER: Array[String] = ["preparation", "offense"]
const PREPARATION_ACTIONS: Array[String] = [
	"block",
	"parry",
	"dodge",
	"reposition",
	"recover",
]
const OFFENSE_ACTIONS: Array[String] = ["light", "heavy"]

var _combat_contract = CombatContractScript.new()
var _policy_contract = CombatPolicyContractScript.new()
var _runtime_builder = CombatRuntimeStateBuilderScript.new()


func inspect_intents(state: Dictionary, intents: Array) -> Dictionary:
	return build_resolution_plan(state, intents)


func build_resolution_plan(state: Dictionary, intents: Array) -> Dictionary:
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected("invalid_state", state_errors, state, intents)

	var intent_errors: Array[String] = _validate_intents(state, intents)
	if not intent_errors.is_empty():
		return _rejected("invalid_intents", intent_errors, state, intents)

	var preparation_intents: Array = []
	var offense_intents: Array = []
	for raw_intent in intents:
		var intent := (raw_intent as Dictionary).duplicate(true)
		var action_id := str(intent.get("action_id", ""))
		if PREPARATION_ACTIONS.has(action_id):
			preparation_intents.append(intent)
		elif OFFENSE_ACTIONS.has(action_id):
			offense_intents.append(intent)

	preparation_intents.sort_custom(_sort_by_actor_id)
	offense_intents.sort_custom(_sort_by_actor_id)

	return {
		"status": "ready",
		"pending": false,
		"reason": "",
		"errors": [],
		"state": state.duplicate(true),
		"submitted_intents": intents.duplicate(true),
		"phase_order": PHASE_ORDER.duplicate(),
		"phases":
		[
			{
				"id": "preparation",
				"simultaneous": true,
				"snapshot": "exchange_start",
				"commit": "end_of_phase",
				"intents": preparation_intents,
			},
			{
				"id": "offense",
				"simultaneous": true,
				"snapshot": "after_preparation_commit",
				"commit": "end_of_phase",
				"intents": offense_intents,
			},
		],
		"initiative_mode": "none",
		"tie_break_mode": "simultaneous",
		"actor_intent_rule": "exactly_one_per_active_fighter",
	}


func get_contract_status() -> Dictionary:
	return {
		"status": "frozen",
		"phase_order": PHASE_ORDER.duplicate(),
		"preparation_actions": PREPARATION_ACTIONS.duplicate(),
		"offense_actions": OFFENSE_ACTIONS.duplicate(),
		"initiative_mode": "none",
		"tie_break_mode": "simultaneous",
		"actor_intent_rule": "exactly_one_per_active_fighter",
	}


func _validate_intents(state: Dictionary, intents: Array) -> Array[String]:
	var errors: Array[String] = []
	var actor_counts: Dictionary = {}
	for index in range(intents.size()):
		var raw_intent: Variant = intents[index]
		if raw_intent is not Dictionary:
			errors.append("Resolution-order intent %d must be a Dictionary" % index)
			continue
		var intent := raw_intent as Dictionary
		var policy_errors: Array[String] = _policy_contract.validate_desired_action(state, intent)
		for error_message in policy_errors:
			errors.append("Intent %d: %s" % [index, error_message])
		var actor_id := str(intent.get("actor_id", ""))
		if not actor_id.is_empty():
			actor_counts[actor_id] = int(actor_counts.get(actor_id, 0)) + 1

	if not errors.is_empty():
		return errors

	var active_fighter_ids := _active_fighter_ids(state)
	for actor_id in actor_counts:
		if not active_fighter_ids.has(str(actor_id)):
			errors.append("Fighter %s is not active for this exchange" % str(actor_id))

	for fighter_id in active_fighter_ids:
		var count := int(actor_counts.get(fighter_id, 0))
		if count == 0:
			errors.append("Fighter %s must submit exactly one intent per exchange" % fighter_id)
		elif count > 1:
			errors.append("Fighter %s submitted more than one intent for the exchange" % fighter_id)

	return errors


func _active_fighter_ids(state: Dictionary) -> Array[String]:
	var fighter_ids: Array[String] = []
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if _runtime_builder.is_knocked_out(fighter):
			continue
		fighter_ids.append(str(fighter.get("id", "")))
	fighter_ids.sort()
	return fighter_ids


func _sort_by_actor_id(left: Variant, right: Variant) -> bool:
	return (
		str((left as Dictionary).get("actor_id", ""))
		< str((right as Dictionary).get("actor_id", ""))
	)


func _rejected(
	status: String, errors: Array[String], state: Dictionary, intents: Array
) -> Dictionary:
	return {
		"status": status,
		"pending": false,
		"reason": "",
		"errors": errors.duplicate(),
		"state": state.duplicate(true),
		"submitted_intents": intents.duplicate(true),
		"phase_order": [],
		"phases": [],
	}
