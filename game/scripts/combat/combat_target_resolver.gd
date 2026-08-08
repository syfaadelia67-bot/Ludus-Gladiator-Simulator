extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const TARGET_RULES_PENDING_REASON := "target_rules_not_frozen"

var _combat_contract = CombatContractScript.new()


func get_candidate_groups(state: Dictionary, actor_id: String) -> Dictionary:
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected("invalid_state", state_errors)

	var actor := _find_fighter(state, actor_id)
	if actor.is_empty():
		return _rejected("invalid_actor", ["Unknown target-resolution actor: %s" % actor_id])

	var allies: Array[String] = []
	var enemies: Array[String] = []
	var actor_team := str(actor.get("team", ""))
	for raw_fighter in state.get("fighters", []) as Array:
		if raw_fighter is not Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		var fighter_id := str(fighter.get("id", ""))
		if fighter_id == actor_id:
			continue
		if str(fighter.get("team", "")) == actor_team:
			allies.append(fighter_id)
		else:
			enemies.append(fighter_id)

	return {
		"status": "ready",
		"pending": false,
		"reason": "",
		"errors": [],
		"actor_id": actor_id,
		"candidates": {"allies": allies, "enemies": enemies},
	}


func inspect_action_targets(state: Dictionary, actor_id: String, action_id: String) -> Dictionary:
	if not _combat_contract.is_action_id_valid(action_id):
		return _rejected("invalid_action", ["Unknown target-resolution action: %s" % action_id])

	var candidate_result := get_candidate_groups(state, actor_id)
	if candidate_result.get("status") != "ready":
		return candidate_result

	return {
		"status": "pending_design_freeze",
		"pending": true,
		"reason": TARGET_RULES_PENDING_REASON,
		"errors": [],
		"actor_id": actor_id,
		"action_id": action_id,
		"candidates": (candidate_result.get("candidates", {}) as Dictionary).duplicate(true),
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


func _rejected(status: String, errors: Array[String]) -> Dictionary:
	return {
		"status": status,
		"pending": false,
		"reason": "",
		"errors": errors.duplicate(),
		"actor_id": "",
		"candidates": {},
	}
