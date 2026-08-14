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
	_test_tactical_plan_uses_first_executable_order()
	_test_tactical_plan_skips_unexecutable_order()
	_test_automatic_policy_recovers_when_no_costly_action_is_affordable()
	_test_automatic_policy_recovers_before_defense_cycle_deadlock()

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
	blackboard.call("set_var", &"skill_mechanics", _skill_mechanics_fixture())
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
	blackboard.call("set_var", &"skill_mechanics", _skill_mechanics_fixture())
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
		"invalid proposal must report policy errors",
	)
	_release_fixture(fixture)


func _test_tactical_plan_uses_first_executable_order() -> void:
	var fixture := _runtime_fixture()
	var blackboard: Object = fixture.get("blackboard")
	_prepare_auto_blackboard(
		blackboard,
		_valid_state(),
		[{"ability_id": "charge", "condition": "always"}],
	)

	(fixture.get("bt_instance") as Object).call("update", 0.0)
	var desired_action := blackboard.call("get_var", &"desired_action", {}) as Dictionary
	_assert_eq(desired_action.get("skill_id"), "charge", "first executable order must win")
	_assert_eq(desired_action.get("target_id"), "b", "enemy skill target must be automatic")
	_release_fixture(fixture)


func _test_tactical_plan_skips_unexecutable_order() -> void:
	var fixture := _runtime_fixture()
	var blackboard: Object = fixture.get("blackboard")
	_prepare_auto_blackboard(
		blackboard,
		_valid_state(),
		[
			{"ability_id": "closed_guard", "condition": "always"},
			{"ability_id": "charge", "condition": "always"},
		],
	)

	(fixture.get("bt_instance") as Object).call("update", 0.0)
	var desired_action := blackboard.call("get_var", &"desired_action", {}) as Dictionary
	_assert_eq(
		desired_action.get("skill_id"),
		"charge",
		"missing shield must skip closed_guard and evaluate the next tactical order",
	)
	_release_fixture(fixture)


func _test_automatic_policy_recovers_when_no_costly_action_is_affordable() -> void:
	var fixture := _runtime_fixture()
	var blackboard: Object = fixture.get("blackboard")
	var state := _valid_state()
	(state.get("fighters", []) as Array)[0]["stamina"] = 0
	_prepare_auto_blackboard(
		blackboard,
		state,
		[{"ability_id": "charge", "condition": "always"}],
	)

	(fixture.get("bt_instance") as Object).call("update", 0.0)
	var desired_action := blackboard.call("get_var", &"desired_action", {}) as Dictionary
	_assert_eq(
		desired_action.get("action_id"),
		"recover",
		"zero stamina must fall back to recover instead of deadlocking",
	)
	_release_fixture(fixture)


func _test_automatic_policy_recovers_before_defense_cycle_deadlock() -> void:
	var fixture := _runtime_fixture()
	var blackboard: Object = fixture.get("blackboard")
	var state := _valid_state()
	(state.get("fighters", []) as Array)[0]["stamina"] = 2
	_prepare_auto_blackboard(blackboard, state, [])

	(fixture.get("bt_instance") as Object).call("update", 0.0)
	var desired_action := blackboard.call("get_var", &"desired_action", {}) as Dictionary
	_assert_eq(
		desired_action.get("action_id"),
		"recover",
		"stamina two must recover instead of spending two on defense forever",
	)
	_release_fixture(fixture)


func _prepare_auto_blackboard(blackboard: Object, state: Dictionary, tactical_plan: Array) -> void:
	blackboard.call("set_var", &"combat_state", state)
	blackboard.call("set_var", &"policy_proposal", {"actor_id": "a", "auto_select": true})
	blackboard.call("set_var", &"tactical_plan", tactical_plan.duplicate(true))
	blackboard.call("set_var", &"skill_mechanics", _skill_mechanics_fixture())
	blackboard.call("set_var", &"exchange_index", 0)
	blackboard.call("set_var", &"last_exchange_result", {})
	(
		blackboard
		. call(
			"set_var",
			&"available_action_ids",
			["light", "heavy", "block", "parry", "dodge", "recover", "reposition"],
		)
	)


func _skill_mechanics_fixture() -> Array:
	return [
		{
			"id": "charge",
			"status": "frozen",
			"mechanics":
			{
				"action_mapping": {"base_action": "heavy", "runtime_effect": "charge_attack"},
				"cost": {"stamina": 6},
				"timing": {"phase": "offense", "trigger": "declared_action"},
				"targets": {"relationship": "enemy", "count": 1},
				"equipment_requirements": [],
				"effects": {"damage_bonus": 2, "self_vulnerable_after_commit": true},
			},
			"progression": {},
		},
		{
			"id": "closed_guard",
			"status": "frozen",
			"mechanics":
			{
				"action_mapping": {"base_action": "block", "runtime_effect": "enhanced_block"},
				"cost": {"stamina": 3},
				"timing": {"phase": "preparation", "trigger": "declared_action"},
				"targets": {"relationship": "self", "count": 0},
				"equipment_requirements": ["shield"],
				"effects": {"flat_damage_reduction_bonus": 2, "applies_to_exchange": true},
			},
			"progression": {},
		},
	]


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
		"stamina_capacity": 100,
		"equipment_context": {"has_weapon": true, "has_shield": false, "tags": []},
	}


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
