@tool
extends BTAction

const CombatActionCatalogScript = preload("res://scripts/combat/combat_action_catalog.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")

const LOW_RESOURCE_RATIO := 0.30

@export var combat_state_var: StringName = &"combat_state"
@export var proposal_var: StringName = &"policy_proposal"
@export var desired_action_var: StringName = &"desired_action"
@export var policy_errors_var: StringName = &"policy_errors"

var _action_catalog = CombatActionCatalogScript.new()
var _policy_contract = CombatPolicyContractScript.new()


func _generate_name() -> String:
	return "Publish Tactical Desired Action"


func _tick(_delta: float) -> Status:
	var state_value: Variant = blackboard.get_var(combat_state_var, {})
	var proposal_value: Variant = blackboard.get_var(proposal_var, {})
	if state_value is not Dictionary or proposal_value is not Dictionary:
		_reject(["Policy proposal requires Dictionary combat_state and policy_proposal"])
		return FAILURE

	var state := state_value as Dictionary
	var proposal := proposal_value as Dictionary
	DataRepository.load_all()
	_policy_contract.set_skill_mechanics(DataRepository.get_skill_mechanics_v1())

	var desired_action := proposal.duplicate(true)
	if bool(proposal.get("auto_select", false)):
		desired_action = _select_automatic_action(state, str(proposal.get("actor_id", "")))
	if desired_action.is_empty():
		_reject(["LimboAI could not select a legal Combat V1 action"])
		return FAILURE

	var errors: Array[String] = _policy_contract.validate_desired_action(state, desired_action)
	if not errors.is_empty():
		_reject(errors)
		return FAILURE

	blackboard.set_var(desired_action_var, desired_action.duplicate(true))
	blackboard.set_var(policy_errors_var, [])
	return SUCCESS


func _select_automatic_action(state: Dictionary, actor_id: String) -> Dictionary:
	var actor := _find_fighter(state, actor_id)
	if actor.is_empty():
		return {}
	var tactical_plan_value: Variant = blackboard.get_var(&"tactical_plan", [])
	if tactical_plan_value is Array:
		for raw_order in tactical_plan_value as Array:
			if raw_order is not Dictionary:
				continue
			var order := raw_order as Dictionary
			if not _condition_matches(state, actor, str(order.get("condition", "always"))):
				continue
			var skill_action := _build_skill_action(state, actor, str(order.get("ability_id", "")))
			if not skill_action.is_empty():
				return skill_action
	return _build_basic_fallback(state, actor)


func _build_skill_action(state: Dictionary, actor: Dictionary, skill_id: String) -> Dictionary:
	if skill_id.is_empty():
		return {}
	var entry := _skill_mechanics(skill_id)
	if entry.is_empty():
		return {}
	var mechanics := entry.get("mechanics", {}) as Dictionary
	var stamina_cost := int((mechanics.get("cost", {}) as Dictionary).get("stamina", 0))
	if float(actor.get("stamina", 0.0)) < float(stamina_cost):
		return {}

	var desired_action := {
		"actor_id": str(actor.get("id", "")),
		"skill_id": skill_id,
	}
	var targets := mechanics.get("targets", {}) as Dictionary
	if int(targets.get("count", 0)) > 0:
		var target_id := _select_target(state, actor, str(targets.get("relationship", "")))
		if target_id.is_empty():
			return {}
		desired_action["target_id"] = target_id
	if not _policy_contract.validate_desired_action(state, desired_action).is_empty():
		return {}
	return desired_action


func _build_basic_fallback(state: Dictionary, actor: Dictionary) -> Dictionary:
	var actor_id := str(actor.get("id", ""))
	var stamina := float(actor.get("stamina", 0.0))
	var enemies := _active_fighters_by_relationship(state, actor, "enemy")
	var preferred_actions: Array[String] = ["light", "block", "parry", "reposition", "recover"]
	for action_id in preferred_actions:
		if not (blackboard.get_var(&"available_action_ids", []) as Array).has(action_id):
			continue
		var contract := _action_catalog.get_action_contract(action_id)
		if contract.is_empty() or stamina < float(contract.get("stamina_cost", 0)):
			continue
		var desired_action := {"actor_id": actor_id, "action_id": action_id}
		if bool(contract.get("target_required", false)):
			if enemies.is_empty():
				continue
			desired_action["target_id"] = str(enemies[0].get("id", ""))
		if _policy_contract.validate_desired_action(state, desired_action).is_empty():
			return desired_action
	return {"actor_id": actor_id, "action_id": "recover"}


func _condition_matches(state: Dictionary, actor: Dictionary, condition: String) -> bool:
	match condition:
		"always":
			return true
		"opening":
			return int(blackboard.get_var(&"exchange_index", 0)) == 0
		"target_vulnerable":
			return _any_enemy_matches(
				state, actor, func(enemy: Dictionary): return bool(enemy.get("vulnerable", false))
			)
		"target_guarding":
			return _target_was_guarding(actor)
		"target_low_energy":
			return _any_enemy_matches(
				state,
				actor,
				func(enemy: Dictionary): return _stamina_ratio(enemy) <= LOW_RESOURCE_RATIO
			)
		"self_low_health":
			return _health_ratio(actor) <= LOW_RESOURCE_RATIO
		"self_low_energy":
			return _stamina_ratio(actor) <= LOW_RESOURCE_RATIO
		"after_defense":
			return _actor_defended_last_exchange(str(actor.get("id", "")))
		_:
			return false


func _target_was_guarding(actor: Dictionary) -> bool:
	var enemy_ids: Array[String] = []
	for enemy in _active_fighters_by_relationship(
		blackboard.get_var(combat_state_var, {}) as Dictionary, actor, "enemy"
	):
		enemy_ids.append(str(enemy.get("id", "")))
	var last_exchange := blackboard.get_var(&"last_exchange_result", {}) as Dictionary
	for raw_intent in last_exchange.get("submitted_intents", []) as Array:
		if raw_intent is not Dictionary:
			continue
		var intent := raw_intent as Dictionary
		if (
			enemy_ids.has(str(intent.get("actor_id", "")))
			and str(intent.get("action_id", "")) in ["block", "parry"]
		):
			return true
	return false


func _actor_defended_last_exchange(actor_id: String) -> bool:
	var last_exchange := blackboard.get_var(&"last_exchange_result", {}) as Dictionary
	for raw_intent in last_exchange.get("submitted_intents", []) as Array:
		if raw_intent is not Dictionary:
			continue
		var intent := raw_intent as Dictionary
		if (
			str(intent.get("actor_id", "")) == actor_id
			and str(intent.get("action_id", "")) in ["block", "parry", "dodge", "reposition"]
		):
			return true
	for raw_attack in last_exchange.get("attack_results", []) as Array:
		if raw_attack is not Dictionary:
			continue
		var attack := raw_attack as Dictionary
		if str(attack.get("target_id", "")) != actor_id:
			continue
		var defense := attack.get("defense_result", {}) as Dictionary
		if (
			bool(defense.get("blocked", false))
			or bool(defense.get("parried", false))
			or bool(defense.get("dodged", false))
		):
			return true
	return false


func _select_target(state: Dictionary, actor: Dictionary, relationship: String) -> String:
	if relationship == "self":
		return str(actor.get("id", ""))
	var candidates := _active_fighters_by_relationship(state, actor, relationship)
	if candidates.is_empty():
		return ""
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if relationship == "enemy":
				var a_ratio := _health_ratio(a)
				var b_ratio := _health_ratio(b)
				if not is_equal_approx(a_ratio, b_ratio):
					return a_ratio < b_ratio
			return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return str(candidates[0].get("id", ""))


func _active_fighters_by_relationship(
	state: Dictionary, actor: Dictionary, relationship: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var actor_id := str(actor.get("id", ""))
	var actor_team := str(actor.get("team", ""))
	for raw_fighter in state.get("fighters", []) as Array:
		if raw_fighter is not Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("id", "")) == actor_id or _health_ratio(fighter) <= 0.0:
			continue
		var same_team := str(fighter.get("team", "")) == actor_team
		if (relationship == "ally" and same_team) or (relationship == "enemy" and not same_team):
			result.append(fighter)
	return result


func _any_enemy_matches(state: Dictionary, actor: Dictionary, predicate: Callable) -> bool:
	for enemy in _active_fighters_by_relationship(state, actor, "enemy"):
		if predicate.call(enemy):
			return true
	return false


func _health_ratio(fighter: Dictionary) -> float:
	var stats := fighter.get("stats", {}) as Dictionary
	var maximum := maxf(1.0, float(stats.get("PV", 1.0)))
	return float(fighter.get("current_pv", maximum)) / maximum


func _stamina_ratio(fighter: Dictionary) -> float:
	var maximum := maxf(1.0, float(fighter.get("stamina_capacity", 100.0)))
	return float(fighter.get("stamina", 0.0)) / maximum


func _skill_mechanics(skill_id: String) -> Dictionary:
	for raw_entry in DataRepository.get_skill_mechanics_v1():
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("id", "")) == skill_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _find_fighter(state: Dictionary, fighter_id: String) -> Dictionary:
	for raw_fighter in state.get("fighters", []) as Array:
		if (
			raw_fighter is Dictionary
			and str((raw_fighter as Dictionary).get("id", "")) == fighter_id
		):
			return raw_fighter as Dictionary
	return {}


func _reject(errors: Array[String]) -> void:
	blackboard.set_var(desired_action_var, {})
	blackboard.set_var(policy_errors_var, errors.duplicate())
