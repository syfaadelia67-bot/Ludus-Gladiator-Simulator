extends SceneTree

const CombatDecisionGatewayScript = preload("res://scripts/combat/combat_decision_gateway.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_valid_proposal_reaches_simulator_as_pending()
	_test_invalid_target_proposal_stops_before_simulator()
	_test_invalid_proposal_stops_before_simulator()
	_test_unknown_actor_stops_before_simulator()

	if _failures.is_empty():
		print("Combat decision gateway: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_valid_proposal_reaches_simulator_as_pending() -> void:
	var fixture := _runtime_fixture()
	var state := _valid_state()
	var proposal := {"actor_id": "a", "action_id": "light", "target_id": "b"}
	var state_before := state.duplicate(true)
	var proposal_before := proposal.duplicate(true)
	var gateway = CombatDecisionGatewayScript.new()
	var result: Dictionary = gateway.resolve_proposal(
		state, "a", proposal, fixture.agent, fixture.owner
	)

	_assert_eq(result.get("status"), "pending", "valid proposal must reach simulator boundary")
	_assert_eq(result.get("pending"), true, "single proposal must wait for complete exchange")
	_assert_eq(
		result.get("reason"),
		"complete_exchange_required",
		"gateway must preserve complete-exchange requirement"
	)
	_assert_eq(
		result.get("blocking_requirement"),
		"complete_exchange_intents",
		"gateway must request all fighter intents before resolution",
	)
	var blocking_context := result.get("blocking_context", {}) as Dictionary
	var target_context := blocking_context.get("resolved_target_context", {}) as Dictionary
	_assert_eq(target_context.get("status"), "ready", "gateway must expose resolved D1 context")
	_assert_eq(target_context.get("legal_targets"), ["b"], "gateway must expose legal enemy target")
	var order_contract := blocking_context.get("resolution_order_contract", {}) as Dictionary
	_assert_eq(order_contract.get("status"), "frozen", "gateway must expose frozen D3 contract")
	_assert_eq(
		order_contract.get("phase_order"),
		["preparation", "offense"],
		"D3 phases must survive gateway"
	)
	var damage_contract := blocking_context.get("damage_contract", {}) as Dictionary
	_assert_eq(damage_contract.get("status"), "frozen", "gateway must expose frozen D4 contract")
	var stamina_contract := blocking_context.get("stamina_contract", {}) as Dictionary
	_assert_eq(stamina_contract.get("status"), "frozen", "gateway must expose frozen D6 contract")
	var accuracy_contract := blocking_context.get("accuracy_contract", {}) as Dictionary
	_assert_eq(accuracy_contract.get("status"), "frozen", "gateway must expose frozen D7 contract")
	var defense_contract := blocking_context.get("defensive_effect_contract", {}) as Dictionary
	_assert_eq(defense_contract.get("status"), "frozen", "gateway must expose frozen defenses")
	var exchange_contract := blocking_context.get("exchange_contract", {}) as Dictionary
	_assert_eq(exchange_contract.get("status"), "frozen", "gateway must expose exchange contract")
	_assert_eq(
		exchange_contract.get("offense_commit"), "simultaneous", "exchange must stay simultaneous"
	)
	var combat_end_contract := blocking_context.get("combat_end_contract", {}) as Dictionary
	_assert_eq(
		combat_end_contract.get("status"), "frozen", "gateway must expose combat-end contract"
	)
	_assert_eq(
		combat_end_contract.get("automatic_surrender"),
		"disabled_v1",
		"gateway must expose frozen surrender behavior",
	)
	_assert_eq(
		result.get("desired_action", {}), proposal_before, "gateway must expose validated intent"
	)
	_assert_true(
		(
			result.get("simulation", {}) is Dictionary
			and not (result.get("simulation", {}) as Dictionary).is_empty()
		),
		"valid proposal must include simulator result"
	)
	var pending_requirements := result.get("pending_requirements", []) as Array
	_assert_true(pending_requirements.is_empty(), "all mandatory Combat V1 decisions are frozen")
	var frozen_requirements := result.get("frozen_requirements", []) as Array
	_assert_true(frozen_requirements.has("target_rules"), "D1 must remain frozen")
	_assert_true(frozen_requirements.has("resolution_order"), "D3 must remain frozen")
	_assert_true(frozen_requirements.has("damage_and_mitigation"), "D4 must remain frozen")
	_assert_true(frozen_requirements.has("stamina_cost_table"), "D6 must remain frozen")
	_assert_true(frozen_requirements.has("accuracy_formula"), "D7 must remain frozen")
	_assert_true(frozen_requirements.has("defensive_action_effects"), "defenses are frozen")
	_assert_true(frozen_requirements.has("stat_scaling_weights"), "D8 weights are frozen")
	_assert_true(frozen_requirements.has("surrender_rules"), "D9 surrender must be frozen")
	_assert_true(frozen_requirements.has("combat_end_rules"), "combat-end rules must be frozen")
	_assert_true(frozen_requirements.has("carryover"), "D10 carryover must be frozen")
	var conditional_requirements := result.get("conditional_requirements", []) as Array
	_assert_true(
		conditional_requirements.has("position_and_distance_model"),
		"gateway must keep D2 conditional until explicitly frozen"
	)
	_assert_eq(state, state_before, "gateway must not mutate CombatState")
	_assert_eq(proposal, proposal_before, "gateway must not mutate policy proposal")

	var desired_action := result.get("desired_action", {}) as Dictionary
	desired_action["action_id"] = "heavy"
	_assert_eq(proposal, proposal_before, "gateway result must be isolated from caller proposal")
	frozen_requirements.clear()
	var nested_frozen := (
		(result.get("simulation", {}) as Dictionary).get("frozen_requirements", []) as Array
	)
	_assert_true(
		nested_frozen.has("carryover"),
		"gateway readiness arrays must be isolated from nested simulator result",
	)
	(target_context.get("legal_targets", []) as Array).clear()
	var nested_blocker := (
		(result.get("simulation", {}) as Dictionary).get("blocking_context", {}) as Dictionary
	)
	var nested_target_context := nested_blocker.get("resolved_target_context", {}) as Dictionary
	_assert_eq(
		nested_target_context.get("legal_targets"),
		["b"],
		"gateway target context must be isolated from nested simulator result",
	)
	fixture.owner.free()


func _test_invalid_target_proposal_stops_before_simulator() -> void:
	var fixture := _runtime_fixture()
	var gateway = CombatDecisionGatewayScript.new()
	var result: Dictionary = gateway.resolve_proposal(
		_valid_state(),
		"a",
		{"actor_id": "a", "action_id": "block", "target_id": "b"},
		fixture.agent,
		fixture.owner
	)
	_assert_eq(result.get("status"), "policy_rejected", "invalid D1 target must stop at policy")
	_assert_eq(result.get("simulation", {}), {}, "invalid D1 target must never reach simulator")
	fixture.owner.free()


func _test_invalid_proposal_stops_before_simulator() -> void:
	var fixture := _runtime_fixture()
	var gateway = CombatDecisionGatewayScript.new()
	var result: Dictionary = gateway.resolve_proposal(
		_valid_state(),
		"a",
		{"actor_id": "a", "action_id": "invented_action", "target_id": "b"},
		fixture.agent,
		fixture.owner
	)

	_assert_eq(result.get("status"), "policy_rejected", "invalid proposal must stop at policy")
	_assert_eq(result.get("pending"), false, "policy rejection must not be marked pending")
	_assert_eq(
		result.get("desired_action", {}), {}, "invalid proposal must expose no desired action"
	)
	_assert_eq(result.get("simulation", {}), {}, "invalid proposal must never reach simulator")
	_assert_eq(result.get("blocking_requirement"), "", "policy rejection must expose no blocker")
	_assert_eq(
		result.get("blocking_context", {}), {}, "policy rejection must expose no blocker context"
	)
	_assert_eq(result.get("pending_requirements", []), [], "policy rejection has no readiness")
	_assert_eq(
		result.get("conditional_requirements", []),
		[],
		"policy rejection has no conditional readiness"
	)
	fixture.owner.free()


func _test_unknown_actor_stops_before_simulator() -> void:
	var fixture := _runtime_fixture()
	var gateway = CombatDecisionGatewayScript.new()
	var result: Dictionary = gateway.resolve_proposal(
		_valid_state(),
		"missing",
		{"actor_id": "missing", "action_id": "light", "target_id": "b"},
		fixture.agent,
		fixture.owner
	)

	_assert_eq(
		result.get("status"), "policy_rejected", "unknown actor must stop at policy boundary"
	)
	_assert_eq(
		result.get("reason"), "invalid_actor", "gateway must preserve policy rejection reason"
	)
	_assert_eq(result.get("simulation", {}), {}, "unknown actor must never reach simulator")
	_assert_eq(result.get("blocking_requirement"), "", "unknown actor must expose no blocker")
	_assert_eq(
		result.get("blocking_context", {}), {}, "unknown actor must expose no blocker context"
	)
	_assert_eq(result.get("pending_requirements", []), [], "unknown actor has no readiness")
	fixture.owner.free()


func _runtime_fixture() -> Dictionary:
	var owner := Node.new()
	var agent := Node.new()
	owner.add_child(agent)
	return {"owner": owner, "agent": agent}


func _valid_state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter("a", "alpha"),
			_fighter("b", "beta"),
		],
	}


func _fighter(id: String, team: String) -> Dictionary:
	return {
		"id": id,
		"team": team,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"stamina": 100,
	}


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
