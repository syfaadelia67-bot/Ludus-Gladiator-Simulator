extends SceneTree

const LimboAIPolicyAdapterScript = preload("res://scripts/combat/limboai_policy_adapter.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var adapter = LimboAIPolicyAdapterScript.new()
	var status: Dictionary = adapter.get_runtime_status()
	_assert_eq(status.get("provider"), "limboai", "adapter provider must stay LimboAI")
	_assert_eq(status.get("version_contract"), "1.6.0", "LimboAI integration must stay pinned to 1.6.0")

	var available := bool(status.get("available", false))
	_assert_eq(adapter.is_limboai_available(), available, "runtime availability APIs must agree")

	var runtime: Dictionary = adapter.prepare_runtime_objects()
	if available:
		_assert_eq(runtime.get("status"), "ready", "available LimboAI runtime must initialize")
		var objects_value: Variant = runtime.get("objects", {})
		_assert_true(objects_value is Dictionary, "ready runtime must expose its objects")
		if objects_value is Dictionary:
			var objects := objects_value as Dictionary
			_assert_true(objects.get("bt_player") != null, "BTPlayer must initialize")
			_assert_true(objects.get("behavior_tree") != null, "BehaviorTree must initialize")
			_assert_true(objects.get("blackboard") != null, "Blackboard must initialize")
		adapter.release_runtime_objects(runtime)
	else:
		_assert_eq(runtime.get("status"), "unavailable", "missing extension must degrade safely")
		var missing_value: Variant = status.get("missing_classes", [])
		_assert_true(missing_value is Array and not (missing_value as Array).is_empty(), "unavailable runtime must report missing classes")

	var state := _valid_state()
	var desired_action := {"actor_id": "a", "action_id": "light", "target_id": "b"}
	_assert_true(adapter.validate_policy_output(state, desired_action).is_empty(), "LimboAI output must pass canonical policy validation")

	var invalid_action := {"actor_id": "a", "action_id": "invented_action", "target_id": "b"}
	_assert_true(not adapter.validate_policy_output(state, invalid_action).is_empty(), "LimboAI cannot bypass canonical action validation")

	if _failures.is_empty():
		print("LimboAI policy adapter contract: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _valid_state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters": [
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
