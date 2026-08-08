extends SceneTree

const LimboAIPolicyAdapterScript = preload("res://scripts/combat/limboai_policy_adapter.gd")
const LimboAIPolicyTreeFactoryScript = preload("res://scripts/combat/limboai_policy_tree_factory.gd")
const CombatSimulatorScript = preload("res://scripts/combat/combat_simulator.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_valid_proposal_reaches_simulator()
	_test_invalid_proposal_never_reaches_simulator()

	if _failures.is_empty():
		print("LimboAI policy pipeline: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_valid_proposal_reaches_simulator() -> void:
	var fixture := _pipeline_fixture()
	if fixture.is_empty():
		return
	var state := _valid_state()
	var adapter = fixture.get("adapter")
	var runtime := fixture.get("runtime") as Dictionary
	var context_result: Dictionary = adapter.build_policy_context(state, "a")
	_assert_eq(context_result.get("status"), "ready", "valid actor must build policy context")
	var context := context_result.get("context", {}) as Dictionary
	var write_result: Dictionary = adapter.write_policy_context_to_blackboard(runtime, context)
	_assert_eq(write_result.get("status"), "ready", "context must seed Blackboard")

	var blackboard: Object = (runtime.get("objects") as Dictionary).get("blackboard") as Object
	blackboard.call(
		"set_var",
		&"policy_proposal",
		{"actor_id": "a", "action_id": "light", "target_id": "b"},
	)
	(fixture.get("bt_instance") as Object).call("update", 0.0)
	var desired_action: Dictionary = adapter.read_desired_action_from_blackboard(runtime)
	_assert_eq(desired_action.get("action_id"), "light", "tree must publish valid desired action")
	_assert_true(
		adapter.validate_policy_output(state, desired_action).is_empty(),
		"published action must still pass canonical CombatPolicy",
	)

	var simulator = CombatSimulatorScript.new()
	var result: Dictionary = simulator.resolve_intent(state, desired_action)
	_assert_eq(result.get("pending"), true, "valid LimboAI intent must reach simulator boundary")
	_assert_eq(
		result.get("reason"),
		"combat_resolution_rules_not_frozen",
		"simulator must remain pending until combat formulas are frozen",
	)
	_release_fixture(fixture)


func _test_invalid_proposal_never_reaches_simulator() -> void:
	var fixture := _pipeline_fixture()
	if fixture.is_empty():
		return
	var state := _valid_state()
	var adapter = fixture.get("adapter")
	var runtime := fixture.get("runtime") as Dictionary
	var context := (adapter.build_policy_context(state, "a").get("context", {}) as Dictionary)
	adapter.write_policy_context_to_blackboard(runtime, context)

	var blackboard: Object = (runtime.get("objects") as Dictionary).get("blackboard") as Object
	blackboard.call(
		"set_var",
		&"policy_proposal",
		{"actor_id": "a", "action_id": "invented_action", "target_id": "b"},
	)
	(fixture.get("bt_instance") as Object).call("update", 0.0)
	_assert_eq(
		adapter.read_desired_action_from_blackboard(runtime),
		{},
		"invalid proposal must fail closed before simulator",
	)
	var errors_value: Variant = blackboard.call("get_var", &"policy_errors", [])
	_assert_true(
		errors_value is Array and not (errors_value as Array).is_empty(),
		"invalid proposal must preserve policy errors for diagnostics",
	)
	_release_fixture(fixture)


func _pipeline_fixture() -> Dictionary:
	var adapter = LimboAIPolicyAdapterScript.new()
	if not adapter.is_limboai_available():
		_failures.append("LimboAI runtime must be available for policy pipeline contract")
		return {}
	var runtime: Dictionary = adapter.prepare_runtime_objects()
	if runtime.get("status") != "ready":
		_failures.append("LimboAI runtime must initialize for policy pipeline contract")
		return {}

	var factory = LimboAIPolicyTreeFactoryScript.new()
	var behavior_tree: Object = factory.create_policy_tree()
	if behavior_tree == null:
		_failures.append("Policy tree factory must create a BehaviorTree")
		adapter.release_runtime_objects(runtime)
		return {}

	var objects := runtime.get("objects") as Dictionary
	var blackboard: Object = objects.get("blackboard") as Object
	var scene_root := Node.new()
	var agent := Node.new()
	scene_root.add_child(agent)
	var bt_instance: Object = behavior_tree.call("instantiate", agent, blackboard, scene_root, scene_root)
	if bt_instance == null:
		_failures.append("Policy tree must instantiate a BTInstance")
		scene_root.free()
		adapter.release_runtime_objects(runtime)
		return {}
	return {
		"adapter": adapter,
		"runtime": runtime,
		"behavior_tree": behavior_tree,
		"bt_instance": bt_instance,
		"scene_root": scene_root,
	}


func _release_fixture(fixture: Dictionary) -> void:
	var adapter = fixture.get("adapter")
	var runtime := fixture.get("runtime") as Dictionary
	var scene_root: Variant = fixture.get("scene_root")
	if scene_root is Node:
		(scene_root as Node).free()
	adapter.release_runtime_objects(runtime)
	fixture.clear()


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
