extends RefCounted


func build_exchange_events(exchange_index: int, exchange_result: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if str(exchange_result.get("status", "")) != "resolved":
		return events

	(
		events
		. append(
			{
				"type": "exchange_started",
				"exchange_index": exchange_index,
			}
		)
	)
	_append_action_events(events, exchange_index, exchange_result)
	_append_stamina_spend_events(events, exchange_index, exchange_result)
	_append_attack_events(events, exchange_index, exchange_result)
	_append_knockout_events(events, exchange_index, exchange_result)
	_append_stamina_recovery_events(events, exchange_index, exchange_result)
	_append_combat_finished_event(events, exchange_index, exchange_result)
	return events


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"input_authority": "combat_simulator_exchange_result",
		"output_role": "presentation_only",
		"damage_math_allowed": false,
		"hit_math_allowed": false,
		"stamina_math_allowed": false,
		"winner_math_allowed": false,
		"intent_selection_allowed": false,
		"events":
		[
			"exchange_started",
			"action_declared",
			"stamina_spent",
			"attack_resolved",
			"fighter_knocked_out",
			"stamina_recovered",
			"combat_finished",
		],
	}


func _append_action_events(
	events: Array[Dictionary], exchange_index: int, exchange_result: Dictionary
) -> void:
	for raw_intent in exchange_result.get("submitted_intents", []) as Array:
		if not raw_intent is Dictionary:
			continue
		var intent := raw_intent as Dictionary
		var event := {
			"type": "action_declared",
			"exchange_index": exchange_index,
			"actor_id": str(intent.get("actor_id", "")),
			"action_id": str(intent.get("action_id", "")),
			"target_id": str(intent.get("target_id", "")),
		}
		var skill_id := str(intent.get("skill_id", ""))
		if not skill_id.is_empty():
			event["skill_id"] = skill_id
		events.append(event)


func _append_stamina_spend_events(
	events: Array[Dictionary], exchange_index: int, exchange_result: Dictionary
) -> void:
	for raw_spend in exchange_result.get("stamina_spend_results", []) as Array:
		if not raw_spend is Dictionary:
			continue
		var spend := raw_spend as Dictionary
		if str(spend.get("status", "")) != "resolved":
			continue
		var fighter := spend.get("fighter", {}) as Dictionary
		var event := {
			"type": "stamina_spent",
			"exchange_index": exchange_index,
			"fighter_id": str(fighter.get("id", "")),
			"source_id": str(spend.get("action_id", "")),
			"cost": int(spend.get("cost", 0)),
			"stamina_after": float(fighter.get("stamina", 0.0)),
		}
		events.append(event)


func _append_attack_events(
	events: Array[Dictionary], exchange_index: int, exchange_result: Dictionary
) -> void:
	for raw_attack in exchange_result.get("attack_results", []) as Array:
		if not raw_attack is Dictionary:
			continue
		var attack := raw_attack as Dictionary
		var event := {
			"type": "attack_resolved",
			"exchange_index": exchange_index,
			"actor_id": str(attack.get("actor_id", "")),
			"target_id": str(attack.get("target_id", "")),
			"action_id": str(attack.get("action_id", "")),
			"skill_id": str(attack.get("skill_id", "")),
			"hit": bool(attack.get("hit", false)),
			"damage": int(attack.get("damage", 0)),
			"defense_action_id": str(attack.get("defense_action_id", "")),
			"intercepted": bool(attack.get("intercepted", false)),
			"interceptor_id": str(attack.get("interceptor_id", "")),
		}
		events.append(event)


func _append_knockout_events(
	events: Array[Dictionary], exchange_index: int, exchange_result: Dictionary
) -> void:
	for raw_fighter_id in exchange_result.get("ko_fighter_ids", []) as Array:
		var fighter_id := str(raw_fighter_id)
		if fighter_id.is_empty():
			continue
		var event := {
			"type": "fighter_knocked_out",
			"exchange_index": exchange_index,
			"fighter_id": fighter_id,
		}
		events.append(event)


func _append_stamina_recovery_events(
	events: Array[Dictionary], exchange_index: int, exchange_result: Dictionary
) -> void:
	for raw_recovery in exchange_result.get("stamina_recovery_results", []) as Array:
		if not raw_recovery is Dictionary:
			continue
		var recovery := raw_recovery as Dictionary
		if str(recovery.get("status", "")) != "resolved":
			continue
		var fighter := recovery.get("fighter", {}) as Dictionary
		var event := {
			"type": "stamina_recovered",
			"exchange_index": exchange_index,
			"fighter_id": str(fighter.get("id", "")),
			"amount": int(recovery.get("recovery", 0)),
			"timing": str(recovery.get("timing", "")),
			"stamina_after": float(fighter.get("stamina", 0.0)),
		}
		events.append(event)


func _append_combat_finished_event(
	events: Array[Dictionary], exchange_index: int, exchange_result: Dictionary
) -> void:
	if not bool(exchange_result.get("combat_end_resolved", false)):
		return
	var event := {
		"type": "combat_finished",
		"exchange_index": exchange_index,
		"outcome": str(exchange_result.get("outcome", "")),
		"winner_team_id": str(exchange_result.get("winner_team_id", "")),
		"loser_team_id": str(exchange_result.get("loser_team_id", "")),
	}
	events.append(event)
