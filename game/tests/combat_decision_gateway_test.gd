extends SceneTree

const CombatDecisionGatewayScript = preload("res://scripts/combat/combat_decision_gateway.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_valid_proposal_reaches_simulator_as_pending()
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
	_assert_eq(result.get("pending"), true, "combat resolution must remain pending")
	_assert_eq(
		result.get("reason"),
		"combat_resolution_rules_not_frozen",
		"gateway must preserve simulator pending reason"
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
	_assert_true(
		pending_requirements.has("target_rules"), "gateway must surface unresolved target rules"
	)
	_assert_true(
		pending_requirements.has("damage_and_mitigation"),
		"gateway must surface unresolved combat math"
	)
	var conditional_requirements := result.get("conditional_requirements", []) as Array
	_assert_true(
		conditional_requirements.has("position_and_distance_model"),
		"gateway must surface conditional position/distance decision"
	)
	_assert_eq(state, state_before, "gateway must not mutate CombatState")
	_assert_eq(proposal, proposal_before, "gateway must not mutate policy proposal")

	var desired_action := result.get("desired_action", {}) as Dictionary
	desired_action["action_id"] = "heavy"
	_assert_eq(proposal, proposal_before, "gateway result must be isolated from caller proposal")
	pending_requirements.clear()
	_assert_true(
		not (
			((result.get("simulation", {}) as Dictionary).get("pending_requirements", []) as Array)
			. is_empty()
		),
		"gateway readiness arrays must be isolated from nested simulator result"
	)
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
	_assert_eq(
		result.get("pending_requirements", []),
		[],
		"policy rejection must not expose simulator readiness"
	)
	_assert_eq(
		result.get("conditional_requirements", []),
		[],
		"policy rejection must not expose conditional simulator readiness"
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
	_assert_eq(
		result.get("pending_requirements", []),
		[],
		"unknown actor must not expose simulator readiness"
	)
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
