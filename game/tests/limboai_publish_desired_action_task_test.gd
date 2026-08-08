extends SceneTree

const PublishDesiredActionTaskScript = preload("res://ai/tasks/combat/publish_desired_action.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	if not ClassDB.class_exists("BehaviorTree") or not ClassDB.class_exists("Blackboard"):
		push_error("LimboAI runtime classes are required for publish task contract")
		quit(1)
		return

	_test_valid_proposal_publishes()
	_test_invalid_proposal_fails_closed()

	if _failures.is_empty():
		print("LimboAI publish desired action task: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_valid_proposal_publishes() -> void:
	var fixture := _runtime_fixture()
	var blackboard: Object = fixture.get("blackboard")
	blackboard.call("set_var", &"combat_state", _valid_state())
	(
		blackboard
		. call(
			"set_var",
			&"policy_proposal",
			{"actor_id": "a", "action_id": "light", "target_id": "b"},
		)
	)

	var bt_instance: Object = fixture.get("bt_instance")
	bt_instance.call("update", 0.0)
	var desired_action := blackboard.call("get_var", &"desired_action", {}) as Dictionary
	_assert_eq(desired_action.get("action_id"), "light", "valid proposal must be published")
	_assert_eq(
		blackboard.call("get_var", &"policy_errors", []),
		[],
		"valid proposal must clear policy errors",
	)
	_release_fixture(fixture)


func _test_invalid_proposal_fails_closed() -> void:
	var fixture := _runtime_fixture()
	var blackboard: Object = fixture.get("blackboard")
	blackboard.call("set_var", &"combat_state", _valid_state())
	(
		blackboard
		. call(
			"set_var",
			&"policy_proposal",
			{"actor_id": "a", "action_id": "invented_action", "target_id": "b"},
		)
	)
	blackboard.call("set_var", &"desired_action", {"actor_id": "stale", "action_id": "heavy"})

	var bt_instance: Object = fixture.get("bt_instance")
	bt_instance.call("update", 0.0)
	_assert_eq(
		blackboard.call("get_var", &"desired_action", {}),
		{},
		"invalid proposal must clear any stale desired action",
	)
	var errors_value: Variant = blackboard.call("get_var", &"policy_errors", [])
	_assert_true(
		errors_value is Array and not (errors_value as Array).is_empty(),
		"invalid proposal must report policy errors"
	)
	_release_fixture(fixture)


func _runtime_fixture() -> Dictionary:
	var behavior_tree: Object = ClassDB.instantiate("BehaviorTree")
	var blackboard: Object = ClassDB.instantiate("Blackboard")
	var task = PublishDesiredActionTaskScript.new()
	behavior_tree.call("set_root_task", task)

	var scene_root := Node.new()
	var agent := Node.new()
	scene_root.add_child(agent)
	var bt_instance: Object = behavior_tree.call(
		"instantiate", agent, blackboard, scene_root, scene_root
	)
	return {
		"behavior_tree": behavior_tree,
		"blackboard": blackboard,
		"bt_instance": bt_instance,
		"scene_root": scene_root,
	}


func _release_fixture(fixture: Dictionary) -> void:
	var scene_root: Variant = fixture.get("scene_root")
	if scene_root is Node:
		(scene_root as Node).free()
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
