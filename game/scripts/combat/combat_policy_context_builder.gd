extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatTargetResolverScript = preload("res://scripts/combat/combat_target_resolver.gd")

var _combat_contract = CombatContractScript.new()
var _target_resolver = CombatTargetResolverScript.new()


func build_context(state: Dictionary, actor_id: String) -> Dictionary:
	var errors: Array[String] = _combat_contract.validate_state(state)
	if not errors.is_empty():
		return {
			"status": "invalid_state",
			"errors": errors,
			"context": {},
		}

	var actor := _find_fighter(state, actor_id)
	if actor.is_empty():
		return {
			"status": "invalid_actor",
			"errors": ["Policy context references unknown actor: %s" % actor_id],
			"context": {},
		}

	var allies: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	var actor_team := str(actor.get("team", ""))
	for raw_fighter in state.get("fighters", []) as Array:
		if raw_fighter is not Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		var fighter_id := str(fighter.get("id", ""))
		if fighter_id == actor_id:
			continue
		var fighter_copy := fighter.duplicate(true)
		if str(fighter.get("team", "")) == actor_team:
			allies.append(fighter_copy)
		else:
			enemies.append(fighter_copy)

	var target_result := _target_resolver.get_candidate_groups(state, actor_id)
	if target_result.get("status") != "ready":
		return {
			"status": str(target_result.get("status", "invalid_target_context")),
			"errors": (target_result.get("errors", []) as Array).duplicate(),
			"context": {},
		}

	return {
		"status": "ready",
		"errors": [],
		"context":
		{
			"format": str(state.get("format", "")),
			"actor": actor.duplicate(true),
			"actor_id": actor_id,
			"allies": allies,
			"enemies": enemies,
			"available_action_ids": _combat_contract.get_action_ids(),
			"action_contracts": _combat_contract.get_action_contracts(),
			"target_candidates":
			(target_result.get("candidates", {}) as Dictionary).duplicate(true),
			"combat_state": state.duplicate(true),
			"desired_action": {},
		},
	}


func _find_fighter(state: Dictionary, fighter_id: String) -> Dictionary:
	if fighter_id.is_empty():
		return {}
	for raw_fighter in state.get("fighters", []) as Array:
		if (
			raw_fighter is Dictionary
			and str((raw_fighter as Dictionary).get("id", "")) == fighter_id
		):
			return raw_fighter as Dictionary
	return {}
