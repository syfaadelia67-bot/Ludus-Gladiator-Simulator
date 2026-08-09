extends Node

const CombatExchangeResolverScript = preload("res://scripts/combat/combat_exchange_resolver.gd")


func _ready() -> void:
	var resolver = CombatExchangeResolverScript.new()
	_assert_contract(resolver)
	_assert_light_vs_block(resolver)
	_assert_light_vs_dodge(resolver)
	_assert_simultaneous_attacks_commit_together(resolver)
	_assert_insufficient_stamina_rejects_without_mutation(resolver)
	_assert_reposition_clears_vulnerability(resolver)
	_assert_result_is_isolated(resolver)
	print("Combat complete exchange resolver: OK")
	get_tree().quit(0)


func _assert_contract(resolver) -> void:
	var contract: Dictionary = resolver.get_contract()
	assert(contract.get("status") == "frozen")
	assert(contract.get("unit") == "complete_exchange")
	assert(contract.get("offense_commit") == "simultaneous")
	assert(contract.get("damage_aggregation") == "sum_per_target_then_commit")
	assert(contract.get("stamina_recovery_timing") == "end_exchange")
	assert(contract.get("ko_evaluation_timing") == "after_offense_commit")
	assert(contract.get("surrender_resolved") == false)
	assert(contract.get("combat_end_resolved") == false)


func _assert_light_vs_block(resolver) -> void:
	var state := _state()
	var result: Dictionary = (
		resolver
		. resolve_exchange(
			state,
			[
				{"actor_id": "a", "action_id": "light", "target_id": "b"},
				{"actor_id": "b", "action_id": "block"},
			],
		)
	)
	assert(result.get("status") == "resolved")
	var attacks := result.get("attack_results", []) as Array
	assert(attacks.size() == 1)
	var attack := attacks[0] as Dictionary
	assert(attack.get("defense_action_id") == "block")
	assert(((attack.get("defense_result", {}) as Dictionary).get("blocked_amount", 0)) > 0)
	var final_state := result.get("state", {}) as Dictionary
	var a := _fighter_by_id(final_state, "a")
	var b := _fighter_by_id(final_state, "b")
	assert(float(a.get("stamina")) == 9.0)
	assert(float(b.get("stamina")) == 10.0)
	assert(float(b.get("current_pv")) < 20.0)


func _assert_light_vs_dodge(resolver) -> void:
	var result: Dictionary = (
		resolver
		. resolve_exchange(
			_state(),
			[
				{"actor_id": "a", "action_id": "light", "target_id": "b"},
				{"actor_id": "b", "action_id": "dodge"},
			],
		)
	)
	assert(result.get("status") == "resolved")
	var attack := (result.get("attack_results", []) as Array)[0] as Dictionary
	assert(attack.get("hit") == false)
	assert(attack.get("damage") == 0)
	assert((attack.get("defense_result", {}) as Dictionary).get("dodged") == true)
	var b := _fighter_by_id(result.get("state", {}) as Dictionary, "b")
	assert(float(b.get("current_pv")) == 20.0)


func _assert_simultaneous_attacks_commit_together(resolver) -> void:
	var result: Dictionary = (
		resolver
		. resolve_exchange(
			_state(),
			[
				{"actor_id": "a", "action_id": "light", "target_id": "b"},
				{"actor_id": "b", "action_id": "light", "target_id": "a"},
			],
		)
	)
	assert(result.get("status") == "resolved")
	assert((result.get("attack_results", []) as Array).size() == 2)
	var final_state := result.get("state", {}) as Dictionary
	var a := _fighter_by_id(final_state, "a")
	var b := _fighter_by_id(final_state, "b")
	assert(float(a.get("current_pv")) < 20.0)
	assert(float(b.get("current_pv")) < 20.0)
	assert(float(a.get("stamina")) == 9.0)
	assert(float(b.get("stamina")) == 9.0)


func _assert_insufficient_stamina_rejects_without_mutation(resolver) -> void:
	var state := _state()
	var fighters := state.get("fighters", []) as Array
	(fighters[0] as Dictionary)["stamina"] = 2
	var before := state.duplicate(true)
	var result: Dictionary = (
		resolver
		. resolve_exchange(
			state,
			[
				{"actor_id": "a", "action_id": "light", "target_id": "b"},
				{"actor_id": "b", "action_id": "block"},
			],
		)
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "insufficient_stamina")
	assert(state == before)
	assert((result.get("attack_results", []) as Array).is_empty())


func _assert_reposition_clears_vulnerability(resolver) -> void:
	var runtime_state := _runtime_state()
	var b_before := _fighter_by_id(runtime_state, "b")
	b_before["vulnerable"] = true
	var result: Dictionary = (
		resolver
		. resolve_exchange(
			runtime_state,
			[
				{"actor_id": "a", "action_id": "light", "target_id": "b"},
				{"actor_id": "b", "action_id": "reposition"},
			],
		)
	)
	assert(result.get("status") == "resolved")
	var b := _fighter_by_id(result.get("state", {}) as Dictionary, "b")
	assert(b.get("vulnerable") == false)


func _assert_result_is_isolated(resolver) -> void:
	var state := _state()
	var intents := [
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
		{"actor_id": "b", "action_id": "block"},
	]
	var before_state := state.duplicate(true)
	var before_intents := intents.duplicate(true)
	var result: Dictionary = resolver.resolve_exchange(state, intents)
	assert(state == before_state)
	assert(intents == before_intents)
	var result_state := result.get("state", {}) as Dictionary
	(_fighter_by_id(result_state, "a"))["stamina"] = 0
	assert(state == before_state)


func _state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter("a", "alpha"),
			_fighter("b", "beta"),
		],
	}


func _runtime_state() -> Dictionary:
	var state := _state()
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		fighter["current_pv"] = 20.0
		fighter["vulnerable"] = false
		fighter["stamina_capacity"] = 10.0
	return state


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 20},
		"stamina": 10,
		"equipment": {"power": 12, "defense": 0},
	}


func _fighter_by_id(state: Dictionary, fighter_id: String) -> Dictionary:
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("id", "")) == fighter_id:
			return fighter
	return {}
