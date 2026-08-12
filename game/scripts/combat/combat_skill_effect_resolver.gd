extends RefCounted

const DEMO_RUNTIME_RANK := 1


func get_activation(intent: Dictionary) -> Dictionary:
	var value: Variant = intent.get("skill_activation", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func get_skill_id(intent: Dictionary) -> String:
	return str(get_activation(intent).get("skill_id", ""))


func get_stamina_cost(intent: Dictionary, base_cost: int) -> int:
	var activation := get_activation(intent)
	if activation.is_empty():
		return base_cost
	var mechanics := activation.get("mechanics", {}) as Dictionary
	var cost := mechanics.get("cost", {}) as Dictionary
	return maxi(0, int(cost.get("stamina", base_cost)))


func validate_intent(state: Dictionary, intent: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var actor := _find_fighter(state, str(intent.get("actor_id", "")))
	if actor.is_empty():
		return errors
	var action_id := str(intent.get("action_id", ""))
	for status in _get_statuses(actor):
		var forbidden := status.get("forbidden_actions", []) as Array
		if forbidden.has(action_id):
			errors.append(
				(
					"Fighter %s cannot use %s while affected by %s"
					% [str(actor.get("id", "")), action_id, str(status.get("id", "skill_status"))]
				)
			)

	var activation := get_activation(intent)
	if activation.is_empty():
		return errors
	if int(activation.get("rank", DEMO_RUNTIME_RANK)) != DEMO_RUNTIME_RANK:
		errors.append("Combat V1 demo runtime supports canonical skill rank 1 only")
	var mechanics := activation.get("mechanics", {}) as Dictionary
	for raw_requirement in mechanics.get("equipment_requirements", []) as Array:
		var requirement := str(raw_requirement)
		if not _meets_equipment_requirement(actor, requirement):
			errors.append(
				(
					"Fighter %s does not meet skill equipment requirement: %s"
					% [str(actor.get("id", "")), requirement]
				)
			)
	return errors


func apply_preparation(state: Dictionary, intents: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for raw_intent in intents:
		var intent := raw_intent as Dictionary
		var activation := get_activation(intent)
		if activation.is_empty():
			continue
		var skill_id := str(activation.get("skill_id", ""))
		var effects := _effects(activation)
		match skill_id:
			"aid":
				var target_id := str(intent.get("target_id", ""))
				var index := _find_fighter_index(state, target_id)
				if index < 0:
					continue
				var fighters := state.get("fighters", []) as Array
				var ally := fighters[index] as Dictionary
				var before := float(ally.get("stamina", 0.0))
				var capacity := float(ally.get("stamina_capacity", before))
				var restore := float(effects.get("ally_stamina_restore", 0.0))
				ally["stamina"] = minf(capacity, before + restore)
				if bool(effects.get("clear_vulnerable", false)):
					ally["vulnerable"] = false
				(
					results
					. append(
						{
							"skill_id": skill_id,
							"actor_id": str(intent.get("actor_id", "")),
							"target_id": target_id,
							"stamina_restored": float(ally.get("stamina", 0.0)) - before,
						}
					)
				)
			"provoke":
				var target_id := str(intent.get("target_id", ""))
				_add_status(
					state,
					target_id,
					{
						"id": "provoke",
						"source_actor_id": str(intent.get("actor_id", "")),
						"damage_penalty_vs_others":
						int(effects.get("marked_target_damage_penalty_vs_others", 0)),
						"remaining_exchanges":
						maxi(1, int(effects.get("mark_duration_exchanges", 1))),
						"fresh": true,
						"consume_current_exchange": true,
					}
				)
				(
					results
					. append(
						{
							"skill_id": skill_id,
							"actor_id": str(intent.get("actor_id", "")),
							"target_id": target_id,
						}
					)
				)
	return results


func resolve_attack_context(
	state: Dictionary, intents: Array, intent: Dictionary, used_interceptors: Dictionary
) -> Dictionary:
	var actor_id := str(intent.get("actor_id", ""))
	var original_target_id := str(intent.get("target_id", ""))
	var target_id := original_target_id
	var interception := _find_interceptor(state, intents, original_target_id, used_interceptors)
	if not interception.is_empty():
		target_id = str(interception.get("actor_id", ""))
		used_interceptors[target_id] = true

	var attacker := _find_fighter(state, actor_id)
	var defender := _find_fighter(state, target_id)
	var power_penalty := _active_power_penalty(attacker)
	if power_penalty > 0:
		var equipment := (attacker.get("equipment", {}) as Dictionary).duplicate(true)
		equipment["power"] = maxi(0, int(equipment.get("power", 0)) - power_penalty)
		attacker["equipment"] = equipment

	var activation := get_activation(intent)
	var effects := _effects(activation)
	var skill_id := str(activation.get("skill_id", ""))
	if skill_id == "demolisher":
		var equipment := (defender.get("equipment", {}) as Dictionary).duplicate(true)
		equipment["defense"] = maxi(
			0, int(equipment.get("defense", 0)) - int(effects.get("defense_ignore", 0))
		)
		defender["equipment"] = equipment

	return {
		"actor_id": actor_id,
		"original_target_id": original_target_id,
		"target_id": target_id,
		"attacker": attacker,
		"defender": defender,
		"skill_id": skill_id,
		"skill_effects": effects.duplicate(true),
		"intercepted": not interception.is_empty(),
		"interceptor_id": str(interception.get("actor_id", "")),
		"interceptor_damage_reduction_bonus":
		int(
			(_effects(interception.get("activation", {}) as Dictionary)).get(
				"interceptor_damage_reduction_bonus", 0
			)
		),
		"power_penalty": power_penalty,
	}


func should_bypass_defense(attack_context: Dictionary, defense_action_id: String) -> bool:
	if str(attack_context.get("skill_id", "")) != "feint":
		return false
	var effects := attack_context.get("skill_effects", {}) as Dictionary
	if defense_action_id == "block":
		return bool(effects.get("ignore_block_bonus", false))
	if defense_action_id == "parry":
		return bool(effects.get("ignore_parry_bonus", false))
	return false


func apply_attack_modifiers(
	state: Dictionary,
	intents: Array,
	intent: Dictionary,
	attack_context: Dictionary,
	attack_result: Dictionary
) -> Dictionary:
	var result := attack_result.duplicate(true)
	var skill_id := str(attack_context.get("skill_id", ""))
	var effects := attack_context.get("skill_effects", {}) as Dictionary
	if bool(result.get("hit", false)):
		match skill_id:
			"charge":
				result["damage"] = (
					int(result.get("damage", 0)) + int(effects.get("damage_bonus", 0))
				)
			"execution":
				var defender := attack_context.get("defender", {}) as Dictionary
				var stats := defender.get("stats", {}) as Dictionary
				var max_pv := maxf(1.0, float(stats.get("PV", 1.0)))
				var ratio := float(defender.get("current_pv", max_pv)) / max_pv
				if ratio <= float(effects.get("target_pv_ratio_threshold", 0.0)):
					result["damage"] = (
						int(result.get("damage", 0))
						+ int(effects.get("damage_bonus_when_threshold_met", 0))
					)

	var target_id := str(attack_context.get("target_id", ""))
	var defense_skill := _skill_activation_for_actor(intents, target_id)
	var defense_skill_id := str(defense_skill.get("skill_id", ""))
	if defense_skill_id in ["closed_guard", "anchor"] and bool(result.get("hit", false)):
		var reduction := int(_effects(defense_skill).get("flat_damage_reduction_bonus", 0))
		result["damage"] = maxi(0, int(result.get("damage", 0)) - reduction)
		result["skill_flat_reduction"] = reduction
	if bool(attack_context.get("intercepted", false)) and bool(result.get("hit", false)):
		var reduction := int(attack_context.get("interceptor_damage_reduction_bonus", 0))
		result["damage"] = maxi(0, int(result.get("damage", 0)) - reduction)
		result["interception_reduction"] = reduction

	var provoke_penalty := _provoke_damage_penalty(
		_find_fighter(state, str(intent.get("actor_id", ""))), target_id
	)
	if provoke_penalty > 0 and bool(result.get("hit", false)):
		result["damage"] = maxi(0, int(result.get("damage", 0)) - provoke_penalty)
		result["provoke_damage_penalty"] = provoke_penalty
	return result


func apply_post_hit_effects(
	state: Dictionary, intents: Array, attack_results: Array
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for raw_result in attack_results:
		var attack := raw_result as Dictionary
		if not bool(attack.get("hit", false)):
			continue
		var actor_id := str(attack.get("actor_id", ""))
		var target_id := str(attack.get("target_id", ""))
		var activation := _skill_activation_for_actor(intents, actor_id)
		var skill_id := str(activation.get("skill_id", ""))
		var effects := _effects(activation)
		match skill_id:
			"disarm":
				_add_status(
					state,
					target_id,
					{
						"id": "disarm",
						"power_penalty": int(effects.get("target_power_penalty", 0)),
						"remaining_exchanges": maxi(1, int(effects.get("duration_exchanges", 1))),
						"fresh": true,
						"consume_current_exchange": false,
					}
				)
				results.append({"skill_id": skill_id, "actor_id": actor_id, "target_id": target_id})
			"immobilization":
				_add_status(
					state,
					target_id,
					{
						"id": "immobilization",
						"forbidden_actions":
						(effects.get("forbidden_actions", []) as Array).duplicate(),
						"remaining_exchanges": maxi(1, int(effects.get("duration_exchanges", 1))),
						"fresh": true,
						"consume_current_exchange": false,
					}
				)
				results.append({"skill_id": skill_id, "actor_id": actor_id, "target_id": target_id})
	return results


func build_counterattack_results(intents: Array, attack_results: Array) -> Array[Dictionary]:
	var counters: Array[Dictionary] = []
	for raw_result in attack_results:
		var attack := raw_result as Dictionary
		var defense := attack.get("defense_result", {}) as Dictionary
		if not bool(defense.get("parried", false)):
			continue
		var defender_id := str(attack.get("target_id", ""))
		var activation := _skill_activation_for_actor(intents, defender_id)
		if str(activation.get("skill_id", "")) != "counterattack":
			continue
		var effects := _effects(activation)
		if not bool(effects.get("requires_successful_parry", false)):
			continue
		var base_damage := int((attack.get("damage_result", {}) as Dictionary).get("damage", 0))
		var ratio := float(effects.get("riposte_damage_ratio", 0.0))
		var damage := maxi(1, int(round(float(base_damage) * ratio)))
		(
			counters
			. append(
				{
					"status": "resolved",
					"errors": [],
					"actor_id": defender_id,
					"target_id": str(attack.get("actor_id", "")),
					"action_id": "counterattack",
					"skill_id": "counterattack",
					"defense_action_id": "",
					"accuracy_result": {},
					"damage_result": {},
					"defense_result": {},
					"hit": true,
					"damage": damage,
					"counterattack": true,
				}
			)
		)
	return counters


func apply_post_commit(state: Dictionary, intents: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for raw_intent in intents:
		var intent := raw_intent as Dictionary
		var activation := get_activation(intent)
		if str(activation.get("skill_id", "")) != "charge":
			continue
		var effects := _effects(activation)
		if not bool(effects.get("self_vulnerable_after_commit", false)):
			continue
		var index := _find_fighter_index(state, str(intent.get("actor_id", "")))
		if index < 0:
			continue
		var fighter := (state.get("fighters", []) as Array)[index] as Dictionary
		fighter["vulnerable"] = true
		results.append(
			{"skill_id": "charge", "actor_id": str(intent.get("actor_id", "")), "vulnerable": true}
		)
	return results


func decay_statuses(state: Dictionary) -> void:
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		var next_statuses: Array = []
		for raw_status in _get_statuses(fighter):
			var status := (raw_status as Dictionary).duplicate(true)
			var fresh := bool(status.get("fresh", false))
			var consume_current := bool(status.get("consume_current_exchange", false))
			if fresh and not consume_current:
				status["fresh"] = false
				next_statuses.append(status)
				continue
			var remaining := maxi(0, int(status.get("remaining_exchanges", 0)) - 1)
			if remaining > 0:
				status["remaining_exchanges"] = remaining
				status["fresh"] = false
				next_statuses.append(status)
		fighter["skill_statuses"] = next_statuses


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"authority": "combat_simulator_subordinate_skill_effects",
		"runtime_rank": DEMO_RUNTIME_RANK,
		"higher_rank_runtime_enabled": false,
		"specialized_category_is_activation_gate": false,
		"equipment_requirements_enforced": true,
		"status_persistence_scope": "combat_runtime_state_only",
		"damage_authority": "combat_simulator",
		"ko_authority": "combat_simulator",
		"winner_authority": "combat_simulator",
		"save_version_change_required": false,
	}


func _find_interceptor(
	state: Dictionary, intents: Array, protected_id: String, used_interceptors: Dictionary
) -> Dictionary:
	var protected := _find_fighter(state, protected_id)
	if protected.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	for raw_intent in intents:
		var intent := raw_intent as Dictionary
		var activation := get_activation(intent)
		if str(activation.get("skill_id", "")) != "interception":
			continue
		if str(intent.get("target_id", "")) != protected_id:
			continue
		var actor_id := str(intent.get("actor_id", ""))
		if used_interceptors.has(actor_id):
			continue
		var interceptor := _find_fighter(state, actor_id)
		if (
			interceptor.is_empty()
			or str(interceptor.get("team", "")) != str(protected.get("team", ""))
		):
			continue
		candidates.append({"actor_id": actor_id, "activation": activation.duplicate(true)})
	candidates.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("actor_id", "")) < str(right.get("actor_id", ""))
	)
	return candidates[0] if not candidates.is_empty() else {}


func _active_power_penalty(fighter: Dictionary) -> int:
	var penalty := 0
	for status in _get_statuses(fighter):
		if str(status.get("id", "")) == "disarm":
			penalty = maxi(penalty, int(status.get("power_penalty", 0)))
	return penalty


func _provoke_damage_penalty(fighter: Dictionary, target_id: String) -> int:
	var penalty := 0
	for status in _get_statuses(fighter):
		if str(status.get("id", "")) != "provoke":
			continue
		if target_id == str(status.get("source_actor_id", "")):
			continue
		penalty = maxi(penalty, int(status.get("damage_penalty_vs_others", 0)))
	return penalty


func _skill_activation_for_actor(intents: Array, actor_id: String) -> Dictionary:
	for raw_intent in intents:
		var intent := raw_intent as Dictionary
		if str(intent.get("actor_id", "")) == actor_id:
			return get_activation(intent)
	return {}


func _effects(activation: Dictionary) -> Dictionary:
	var mechanics := activation.get("mechanics", {}) as Dictionary
	return (mechanics.get("effects", {}) as Dictionary).duplicate(true)


func _meets_equipment_requirement(fighter: Dictionary, requirement: String) -> bool:
	var context := fighter.get("equipment_context", {}) as Dictionary
	match requirement:
		"weapon":
			return bool(context.get("has_weapon", false))
		"shield":
			return bool(context.get("has_shield", false))
		_:
			return (context.get("tags", []) as Array).has(requirement)


func _add_status(state: Dictionary, fighter_id: String, status: Dictionary) -> void:
	var index := _find_fighter_index(state, fighter_id)
	if index < 0:
		return
	var fighter := (state.get("fighters", []) as Array)[index] as Dictionary
	var statuses := _get_statuses(fighter)
	var status_id := str(status.get("id", ""))
	var replaced := false
	for status_index in range(statuses.size()):
		if str((statuses[status_index] as Dictionary).get("id", "")) == status_id:
			statuses[status_index] = status.duplicate(true)
			replaced = true
			break
	if not replaced:
		statuses.append(status.duplicate(true))
	fighter["skill_statuses"] = statuses


func _get_statuses(fighter: Dictionary) -> Array:
	var value: Variant = fighter.get("skill_statuses", [])
	return (value as Array).duplicate(true) if value is Array else []


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
