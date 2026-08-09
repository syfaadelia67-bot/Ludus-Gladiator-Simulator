extends RefCounted

const CombatAccuracyResolverScript = preload("res://scripts/combat/combat_accuracy_resolver.gd")
const CombatDamageResolverScript = preload("res://scripts/combat/combat_damage_resolver.gd")
const CombatDefensiveEffectResolverScript = preload(
	"res://scripts/combat/combat_defensive_effect_resolver.gd"
)
const CombatResolutionOrderBoundaryScript = preload(
	"res://scripts/combat/combat_resolution_order_boundary.gd"
)
const CombatRuntimeStateBuilderScript = preload(
	"res://scripts/combat/combat_runtime_state_builder.gd"
)
const CombatStaminaResolverScript = preload("res://scripts/combat/combat_stamina_resolver.gd")

const OFFENSE_ACTIONS: Array[String] = ["light", "heavy"]
const DEFENSE_ACTIONS: Array[String] = ["block", "parry", "dodge", "reposition"]

var _accuracy_resolver = CombatAccuracyResolverScript.new()
var _damage_resolver = CombatDamageResolverScript.new()
var _defensive_resolver = CombatDefensiveEffectResolverScript.new()
var _order_boundary = CombatResolutionOrderBoundaryScript.new()
var _runtime_builder = CombatRuntimeStateBuilderScript.new()
var _stamina_resolver = CombatStaminaResolverScript.new()


func resolve_exchange(state: Dictionary, intents: Array) -> Dictionary:
	var runtime_result: Dictionary = _prepare_runtime_state(state)
	if runtime_result.get("status") != "ready":
		return _rejected(
			"invalid_runtime_state", runtime_result.get("errors", []) as Array, state, intents
		)

	var runtime_state := (runtime_result.get("state", {}) as Dictionary).duplicate(true)
	var plan: Dictionary = _order_boundary.build_resolution_plan(runtime_state, intents)
	if plan.get("status") != "ready":
		return _rejected("invalid_intents", plan.get("errors", []) as Array, state, intents)

	var payment_errors: Array[String] = _validate_stamina_payments(runtime_state, intents)
	if not payment_errors.is_empty():
		return _rejected("insufficient_stamina", payment_errors, state, intents)

	var working_state := runtime_state.duplicate(true)
	var spend_results: Array = _spend_all_actions(working_state, intents)
	_apply_preparation_commit(working_state, intents)
	var offense_snapshot := working_state.duplicate(true)
	var attack_results: Array = _resolve_offense_phase(offense_snapshot, intents)
	var offense_errors: Array[String] = _collect_attack_errors(attack_results)
	if not offense_errors.is_empty():
		return _rejected("offense_resolution_failed", offense_errors, state, intents)

	_commit_damage(working_state, attack_results)
	var ko_fighter_ids: Array[String] = _collect_knockouts(working_state)
	var recovery_results: Array = _recover_all_fighters(working_state)
	var final_errors: Array[String] = _runtime_builder.validate_runtime_state(working_state)
	if not final_errors.is_empty():
		return _rejected("invalid_result_state", final_errors, state, intents)

	return {
		"status": "resolved",
		"ok": true,
		"errors": [],
		"state": working_state.duplicate(true),
		"submitted_intents": intents.duplicate(true),
		"resolution_plan": plan.duplicate(true),
		"stamina_spend_results": spend_results.duplicate(true),
		"attack_results": attack_results.duplicate(true),
		"stamina_recovery_results": recovery_results.duplicate(true),
		"ko_fighter_ids": ko_fighter_ids.duplicate(),
		"surrender_resolved": false,
		"combat_end_resolved": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"authority": "combat_simulator",
		"unit": "complete_exchange",
		"phase_order": ["preparation", "offense", "end_exchange"],
		"offense_commit": "simultaneous",
		"damage_aggregation": "sum_per_target_then_commit",
		"stamina_cost_timing": "before_preparation_commit",
		"stamina_recovery_timing": "end_exchange",
		"ko_evaluation_timing": "after_offense_commit",
		"surrender_resolved": false,
		"combat_end_resolved": false,
	}


func _prepare_runtime_state(state: Dictionary) -> Dictionary:
	if _looks_like_runtime_state(state):
		var runtime_errors: Array[String] = _runtime_builder.validate_runtime_state(state)
		if not runtime_errors.is_empty():
			return {"status": "invalid", "errors": runtime_errors, "state": state.duplicate(true)}
		return {"status": "ready", "errors": [], "state": state.duplicate(true)}
	return _runtime_builder.build(state)


func _looks_like_runtime_state(state: Dictionary) -> bool:
	var fighters := state.get("fighters", []) as Array
	if fighters.is_empty():
		return false
	for raw_fighter in fighters:
		var fighter := raw_fighter as Dictionary
		if not fighter.has("current_pv") or not fighter.has("vulnerable"):
			return false
	return true


func _validate_stamina_payments(state: Dictionary, intents: Array) -> Array[String]:
	var errors: Array[String] = []
	for raw_intent in intents:
		var intent := raw_intent as Dictionary
		var actor_id := str(intent.get("actor_id", ""))
		var action_id := str(intent.get("action_id", ""))
		var fighter: Dictionary = _find_fighter(state, actor_id)
		if fighter.is_empty() or not _stamina_resolver.can_pay(fighter, action_id):
			errors.append("Fighter %s cannot pay Stamina cost for %s" % [actor_id, action_id])
	return errors


func _spend_all_actions(state: Dictionary, intents: Array) -> Array:
	var results: Array = []
	for raw_intent in intents:
		var intent := raw_intent as Dictionary
		var actor_id := str(intent.get("actor_id", ""))
		var action_id := str(intent.get("action_id", ""))
		var fighter_index: int = _find_fighter_index(state, actor_id)
		var fighters := state.get("fighters", []) as Array
		var fighter := fighters[fighter_index] as Dictionary
		var spend_result: Dictionary = _stamina_resolver.spend(fighter, action_id)
		fighters[fighter_index] = (spend_result.get("fighter", {}) as Dictionary).duplicate(true)
		results.append(spend_result.duplicate(true))
	return results


func _apply_preparation_commit(state: Dictionary, intents: Array) -> void:
	for raw_intent in intents:
		var intent := raw_intent as Dictionary
		if str(intent.get("action_id", "")) != "reposition":
			continue
		var fighter_index: int = _find_fighter_index(state, str(intent.get("actor_id", "")))
		if fighter_index < 0:
			continue
		var fighters := state.get("fighters", []) as Array
		var fighter := fighters[fighter_index] as Dictionary
		fighter["vulnerable"] = false


func _resolve_offense_phase(state: Dictionary, intents: Array) -> Array:
	var results: Array = []
	var defense_by_actor: Dictionary = _build_defense_action_map(intents)
	for raw_intent in intents:
		var intent := raw_intent as Dictionary
		var action_id := str(intent.get("action_id", ""))
		if not OFFENSE_ACTIONS.has(action_id):
			continue
		var actor_id := str(intent.get("actor_id", ""))
		var target_id := str(intent.get("target_id", ""))
		var attacker: Dictionary = _find_fighter(state, actor_id)
		var defender: Dictionary = _find_fighter(state, target_id)
		var accuracy: Dictionary = _accuracy_resolver.resolve_hit(attacker, defender, action_id)
		var damage: Dictionary = _damage_resolver.resolve_damage(attacker, defender, action_id)
		var attack_result := _base_attack_result(actor_id, target_id, action_id, accuracy, damage)
		var defense_action_id := str(defense_by_actor.get(target_id, ""))
		if DEFENSE_ACTIONS.has(defense_action_id):
			var defended: Dictionary = _defensive_resolver.resolve_against_attack(
				attacker, defender, action_id, defense_action_id, accuracy, damage
			)
			attack_result["defense_action_id"] = defense_action_id
			attack_result["defense_result"] = defended.duplicate(true)
			attack_result["status"] = str(defended.get("status", "invalid"))
			attack_result["errors"] = (defended.get("errors", []) as Array).duplicate()
			attack_result["hit"] = bool(defended.get("hit", false))
			attack_result["damage"] = int(defended.get("damage", 0))
		results.append(attack_result)
	return results


func _base_attack_result(
	actor_id: String, target_id: String, action_id: String, accuracy: Dictionary, damage: Dictionary
) -> Dictionary:
	var errors: Array = []
	if accuracy.get("status") != "resolved":
		errors.append_array(accuracy.get("errors", []) as Array)
	if damage.get("status") != "resolved":
		errors.append_array(damage.get("errors", []) as Array)
	var hit := bool(accuracy.get("hit", false))
	return {
		"status": "resolved" if errors.is_empty() else "invalid",
		"errors": errors,
		"actor_id": actor_id,
		"target_id": target_id,
		"action_id": action_id,
		"defense_action_id": "",
		"accuracy_result": accuracy.duplicate(true),
		"damage_result": damage.duplicate(true),
		"defense_result": {},
		"hit": hit,
		"damage": int(damage.get("damage", 0)) if hit else 0,
	}


func _build_defense_action_map(intents: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_intent in intents:
		var intent := raw_intent as Dictionary
		var action_id := str(intent.get("action_id", ""))
		if DEFENSE_ACTIONS.has(action_id):
			result[str(intent.get("actor_id", ""))] = action_id
	return result


func _collect_attack_errors(attack_results: Array) -> Array[String]:
	var errors: Array[String] = []
	for raw_result in attack_results:
		var result := raw_result as Dictionary
		if result.get("status") == "resolved":
			continue
		for raw_error in result.get("errors", []) as Array:
			errors.append(str(raw_error))
	return errors


func _commit_damage(state: Dictionary, attack_results: Array) -> void:
	var damage_by_target: Dictionary = {}
	for raw_result in attack_results:
		var result := raw_result as Dictionary
		var target_id := str(result.get("target_id", ""))
		damage_by_target[target_id] = (
			int(damage_by_target.get(target_id, 0)) + int(result.get("damage", 0))
		)
	for target_id in damage_by_target:
		var fighter_index: int = _find_fighter_index(state, str(target_id))
		if fighter_index < 0:
			continue
		var fighters := state.get("fighters", []) as Array
		var fighter := fighters[fighter_index] as Dictionary
		fighter["current_pv"] = maxf(
			0.0,
			float(fighter.get("current_pv", 0.0)) - float(damage_by_target[target_id]),
		)


func _collect_knockouts(state: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if _runtime_builder.is_knocked_out(fighter):
			ids.append(str(fighter.get("id", "")))
	return ids


func _recover_all_fighters(state: Dictionary) -> Array:
	var results: Array = []
	var fighters := state.get("fighters", []) as Array
	for index in range(fighters.size()):
		var fighter := fighters[index] as Dictionary
		var recovery: Dictionary = _stamina_resolver.recover(fighter)
		fighters[index] = (recovery.get("fighter", {}) as Dictionary).duplicate(true)
		results.append(recovery.duplicate(true))
	return results


func _find_fighter(state: Dictionary, fighter_id: String) -> Dictionary:
	var index := _find_fighter_index(state, fighter_id)
	if index < 0:
		return {}
	return ((state.get("fighters", []) as Array)[index] as Dictionary).duplicate(true)


func _find_fighter_index(state: Dictionary, fighter_id: String) -> int:
	var fighters := state.get("fighters", []) as Array
	for index in range(fighters.size()):
		var fighter := fighters[index] as Dictionary
		if str(fighter.get("id", "")) == fighter_id:
			return index
	return -1


func _rejected(reason: String, errors: Array, state: Dictionary, intents: Array) -> Dictionary:
	return {
		"status": "rejected",
		"ok": false,
		"reason": reason,
		"errors": errors.duplicate(),
		"state": state.duplicate(true),
		"submitted_intents": intents.duplicate(true),
		"resolution_plan": {},
		"stamina_spend_results": [],
		"attack_results": [],
		"stamina_recovery_results": [],
		"ko_fighter_ids": [],
		"surrender_resolved": false,
		"combat_end_resolved": false,
	}
