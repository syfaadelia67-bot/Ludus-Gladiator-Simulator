extends Node

const CombatSimulatorScript = preload("res://scripts/combat/combat_simulator.gd")


func _ready() -> void:
	var simulator = CombatSimulatorScript.new()
	_assert_valid_intent_requires_complete_exchange(simulator)
	_assert_invalid_target_intent_is_rejected(simulator)
	_assert_invalid_state_is_rejected(simulator)
	_assert_invalid_intent_is_rejected(simulator)
	_assert_inputs_are_not_mutated(simulator)
	print("Combat Simulator authority boundary: OK")
	get_tree().quit(0)


func _assert_valid_intent_requires_complete_exchange(simulator) -> void:
	var result: Dictionary = simulator.resolve_intent(
		_state(), {"actor_id": "a1", "action_id": "light", "target_id": "b1"}
	)
	assert(not bool(result.get("ok", true)), "One intent must not resolve a complete exchange")
	assert(bool(result.get("pending", false)), "A valid single intent must wait for peer intents")
	assert(str(result.get("reason", "")) == simulator.PENDING_REASON)
	assert((result.get("errors", []) as Array).is_empty())
	assert(
		str(result.get("blocking_requirement", "")) == "complete_exchange_intents",
		"single-intent boundary must request the complete exchange intent set",
	)
	var blocking_context := result.get("blocking_context", {}) as Dictionary
	var target_context := blocking_context.get("resolved_target_context", {}) as Dictionary
	assert(target_context.get("status") == "ready", "D1 target context must remain resolved")
	assert(target_context.get("legal_targets") == ["b1"])
	var order_contract := blocking_context.get("resolution_order_contract", {}) as Dictionary
	assert(order_contract.get("status") == "frozen", "D3 contract must be exposed as frozen")
	assert(order_contract.get("phase_order") == ["preparation", "offense"])
	assert(order_contract.get("initiative_mode") == "none")
	assert(order_contract.get("tie_break_mode") == "simultaneous")
	var damage_contract := blocking_context.get("damage_contract", {}) as Dictionary
	assert(damage_contract.get("status") == "frozen", "D4 contract must be exposed as frozen")
	assert(damage_contract.get("deterministic") == true)
	assert(damage_contract.get("armor_penetration_enabled") == false)
	var stamina_contract := blocking_context.get("stamina_contract", {}) as Dictionary
	assert(stamina_contract.get("status") == "frozen", "D6 contract must be exposed as frozen")
	assert((stamina_contract.get("action_costs", {}) as Dictionary).get("heavy") == 5)
	assert(stamina_contract.get("recovery_amount") == 2)
	assert(stamina_contract.get("recovery_timing") == "end_exchange")
	var accuracy_contract := blocking_context.get("accuracy_contract", {}) as Dictionary
	assert(accuracy_contract.get("status") == "frozen", "D7 contract must be exposed as frozen")
	assert(accuracy_contract.get("deterministic") == true)
	assert(accuracy_contract.get("rng_allowed") == false)
	assert(accuracy_contract.get("critical_hits_enabled") == false)
	assert(accuracy_contract.get("attacker_stat") == "TEC")
	assert(accuracy_contract.get("defender_stat") == "AGI")
	assert(accuracy_contract.get("action_accuracy_modifiers") == {"light": 1.0, "heavy": 0.0})
	var defense_contract := blocking_context.get("defensive_effect_contract", {}) as Dictionary
	assert(defense_contract.get("status") == "frozen")
	assert((defense_contract.get("block", {}) as Dictionary).get("reduction_coefficient") == 0.25)
	var exchange_contract := blocking_context.get("exchange_contract", {}) as Dictionary
	assert(exchange_contract.get("status") == "frozen")
	assert(exchange_contract.get("offense_commit") == "simultaneous")
	var combat_end_contract := blocking_context.get("combat_end_contract", {}) as Dictionary
	assert(combat_end_contract.get("status") == "frozen")
	assert(combat_end_contract.get("finish_condition") == "team_elimination")
	assert(combat_end_contract.get("automatic_surrender") == "disabled_v1")
	var d5_d9_contracts := blocking_context.get("d5_d9_contracts", {}) as Dictionary
	assert((d5_d9_contracts.get("D5", {}) as Dictionary).get("status") == "frozen")
	assert((d5_d9_contracts.get("D7", {}) as Dictionary).get("accuracy_formula_status") == "frozen")
	assert((d5_d9_contracts.get("D8", {}) as Dictionary).get("weights_status") == "frozen")
	assert(
		(d5_d9_contracts.get("D9", {}) as Dictionary).get("ko_condition") == "current_pv_lte_zero"
	)
	assert((d5_d9_contracts.get("D9", {}) as Dictionary).get("surrender_rules_status") == "frozen")
	var runtime_preview := blocking_context.get("runtime_state_preview", {}) as Dictionary
	var runtime_fighter := (runtime_preview.get("fighters", []) as Array)[0] as Dictionary
	assert(runtime_fighter.get("current_pv") == 10.0)
	assert(runtime_fighter.get("vulnerable") == false)
	assert(runtime_fighter.get("stamina_capacity") == 10.0)
	var frozen_requirements := result.get("frozen_requirements", []) as Array
	assert(frozen_requirements.has("damage_and_mitigation"))
	assert(frozen_requirements.has("stamina_cost_table"))
	assert(frozen_requirements.has("accuracy_formula"))
	assert(frozen_requirements.has("defensive_action_effects"))
	assert(frozen_requirements.has("stat_scaling_weights"))
	assert(frozen_requirements.has("complete_exchange_resolution"))
	assert(frozen_requirements.has("ko_structure"))
	assert(frozen_requirements.has("surrender_rules"))
	assert(frozen_requirements.has("combat_end_rules"))
	assert(frozen_requirements.has("carryover"))
	var pending_requirements := result.get("pending_requirements", []) as Array
	assert(pending_requirements.is_empty())
	var conditional_requirements := result.get("conditional_requirements", []) as Array
	assert(conditional_requirements.has("position_and_distance_model"))


func _assert_invalid_target_intent_is_rejected(simulator) -> void:
	var result: Dictionary = simulator.resolve_intent(
		_state(), {"actor_id": "a1", "action_id": "block", "target_id": "b1"}
	)
	assert(not bool(result.get("pending", true)))
	assert(str(result.get("reason", "")) == "invalid_desired_action")
	assert(_contains_error(result.get("errors", []), "does not accept an explicit target"))
	assert(str(result.get("blocking_requirement", "")).is_empty())


func _assert_invalid_state_is_rejected(simulator) -> void:
	var state := _state()
	var first_fighter := (state["fighters"] as Array)[0] as Dictionary
	(first_fighter["stats"] as Dictionary)["RES"] = null
	var result: Dictionary = simulator.resolve_intent(
		state, {"actor_id": "a1", "action_id": "light", "target_id": "b1"}
	)
	assert(not bool(result.get("pending", true)))
	assert(str(result.get("reason", "")) == "invalid_state")
	assert(_contains_error(result.get("errors", []), "unresolved stat RES"))
	assert((result.get("frozen_requirements", []) as Array).is_empty())
	assert((result.get("pending_requirements", []) as Array).is_empty())
	assert(str(result.get("blocking_requirement", "")).is_empty())
	assert((result.get("blocking_context", {}) as Dictionary).is_empty())


func _assert_invalid_intent_is_rejected(simulator) -> void:
	var result: Dictionary = simulator.resolve_intent(
		_state(), {"actor_id": "a1", "action_id": "unsupported"}
	)
	assert(not bool(result.get("pending", true)))
	assert(str(result.get("reason", "")) == "invalid_desired_action")
	assert(_contains_error(result.get("errors", []), "unsupported action"))
	assert((result.get("frozen_requirements", []) as Array).is_empty())
	assert((result.get("pending_requirements", []) as Array).is_empty())
	assert(str(result.get("blocking_requirement", "")).is_empty())
	assert((result.get("blocking_context", {}) as Dictionary).is_empty())


func _assert_inputs_are_not_mutated(simulator) -> void:
	var state := _state()
	var desired := {"actor_id": "a1", "action_id": "dodge"}
	var state_before := state.duplicate(true)
	var desired_before := desired.duplicate(true)
	simulator.resolve_intent(state, desired)
	assert(state == state_before, "CombatSimulator boundary must not mutate CombatState")
	assert(desired == desired_before, "CombatSimulator boundary must not mutate desired action")


func _state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter("a1", "a"),
			_fighter("b1", "b"),
		],
	}


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 10},
		"stamina": 10,
	}


func _contains_error(errors_value: Variant, fragment: String) -> bool:
	if not errors_value is Array:
		return false
	for raw_error in errors_value as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
