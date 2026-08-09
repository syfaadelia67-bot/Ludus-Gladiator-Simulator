extends Node

const CombatSimulatorScript = preload("res://scripts/combat/combat_simulator.gd")


func _ready() -> void:
	var simulator = CombatSimulatorScript.new()
	_assert_simulator_resolves_complete_exchange(simulator)
	_assert_simulator_keeps_combat_completion_pending(simulator)
	_assert_simulator_rejects_incomplete_exchange(simulator)
	print("Combat Simulator complete exchange authority: OK")
	get_tree().quit(0)


func _assert_simulator_resolves_complete_exchange(simulator) -> void:
	var state := _state()
	var intents := [
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
		{"actor_id": "b", "action_id": "block"},
	]
	var before_state := state.duplicate(true)
	var before_intents := intents.duplicate(true)
	var result: Dictionary = simulator.resolve_exchange(state, intents)
	assert(result.get("status") == "resolved")
	assert(result.get("ok") == true)
	assert((result.get("attack_results", []) as Array).size() == 1)
	assert((result.get("frozen_requirements", []) as Array).has("complete_exchange_resolution"))
	assert((result.get("frozen_requirements", []) as Array).has("defensive_action_effects"))
	assert((result.get("frozen_requirements", []) as Array).has("stat_scaling_weights"))
	assert(state == before_state)
	assert(intents == before_intents)


func _assert_simulator_keeps_combat_completion_pending(simulator) -> void:
	var result: Dictionary = simulator.resolve_exchange(
		_state(),
		[
			{"actor_id": "a", "action_id": "light", "target_id": "b"},
			{"actor_id": "b", "action_id": "light", "target_id": "a"},
		],
	)
	assert(result.get("status") == "resolved")
	assert(result.get("combat_completion_pending") == true)
	var pending := result.get("pending_requirements", []) as Array
	assert(pending == ["surrender_rules", "carryover"])
	assert((result.get("conditional_requirements", []) as Array).has("position_and_distance_model"))
	assert(result.get("surrender_resolved") == false)
	assert(result.get("combat_end_resolved") == false)


func _assert_simulator_rejects_incomplete_exchange(simulator) -> void:
	var result: Dictionary = simulator.resolve_exchange(
		_state(),
		[
			{"actor_id": "a", "action_id": "light", "target_id": "b"},
		],
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "invalid_intents")
	assert(result.get("ok") == false)


func _state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters": [
			_fighter("a", "alpha"),
			_fighter("b", "beta"),
		],
	}


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 20},
		"stamina": 10,
		"equipment": {"power": 12, "defense": 0},
	}
