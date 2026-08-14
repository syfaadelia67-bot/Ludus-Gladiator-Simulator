extends SceneTree

const LimboAIPolicyRunnerScript = preload("res://scripts/combat/limboai_policy_runner.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_valid_proposal_returns_isolated_desired_action()
	_test_invalid_proposal_fails_closed()
	_test_invalid_runtime_owner_is_rejected()
	_test_unknown_actor_is_rejected()

	if _failures.is_empty():
		print("LimboAI policy runner: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_valid_proposal_returns_isolated_desired_action() -> void:
	var fixture := _runtime_fixture()
	var state := _valid_state()
	var proposal := {"actor_id": "a", "action_id": "light", "target_id": "b"}
	var state_before := state.duplicate(true)
	var proposal_before := proposal.duplicate(true)
	var runner = LimboAIPolicyRunnerScript.new()
	var result: Dictionary = runner.evaluate_proposal(
		state, "a", proposal, fixture.agent, fixture.owner
	)

	_assert_eq(result.get("status"), "ready", "valid proposal must be ready")
	_assert_eq(result.get("provider"), "limboai", "runner must identify LimboAI provider")
	_assert_eq(
		result.get("desired_action", {}),
		proposal_before,
		"valid proposal must become desired action"
	)
	_assert_eq(state, state_before, "runner must not mutate CombatState")
	_assert_eq(proposal, proposal_before, "runner must not mutate the proposal")

	var desired_action := result.get("desired_action", {}) as Dictionary
	desired_action["action_id"] = "heavy"
	_assert_eq(
		proposal, proposal_before, "returned desired action must be isolated from caller proposal"
	)
	fixture.owner.free()


func _test_invalid_proposal_fails_closed() -> void:
	var fixture := _runtime_fixture()
	var runner = LimboAIPolicyRunnerScript.new()
	var result: Dictionary = runner.evaluate_proposal(
		_valid_state(),
		"a",
		{"actor_id": "a", "action_id": "invented_action", "target_id": "b"},
		fixture.agent,
		fixture.owner
	)

	_assert_eq(result.get("status"), "proposal_rejected", "invalid proposal must fail closed")
	_assert_eq(
		result.get("desired_action", {}), {}, "invalid proposal must not expose desired action"
	)
	_assert_true(
		result.get("errors", []) is Array and not (result.get("errors", []) as Array).is_empty(),
		"invalid proposal must preserve policy diagnostics"
	)
	fixture.owner.free()


func _test_invalid_runtime_owner_is_rejected() -> void:
	var runner = LimboAIPolicyRunnerScript.new()
	var result: Dictionary = runner.evaluate_proposal(
		_valid_state(), "a", {"actor_id": "a", "action_id": "light", "target_id": "b"}, null, null
	)
	_assert_eq(
		result.get("status"), "invalid_runtime_owner", "runner must reject missing runtime owners"
	)
	_assert_eq(
		result.get("desired_action", {}), {}, "runtime rejection must not expose desired action"
	)


func _test_unknown_actor_is_rejected() -> void:
	var fixture := _runtime_fixture()
	var runner = LimboAIPolicyRunnerScript.new()
	var result: Dictionary = runner.evaluate_proposal(
		_valid_state(),
		"missing",
		{"actor_id": "missing", "action_id": "light", "target_id": "b"},
		fixture.agent,
		fixture.owner
	)
	_assert_eq(result.get("status"), "invalid_actor", "runner must reject unknown actor")
	_assert_eq(result.get("desired_action", {}), {}, "unknown actor must not expose desired action")
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
