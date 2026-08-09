extends SceneTree

const CombatRuntimeStateBuilderScript = preload("res://scripts/combat/combat_runtime_state_builder.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var builder = CombatRuntimeStateBuilderScript.new()
	_test_build_initializes_runtime_fields(builder)
	_test_invalid_state_is_rejected(builder)
	_test_runtime_validation(builder)
	_test_ko_threshold(builder)
	_test_copy_isolation(builder)

	if _failures.is_empty():
		print("Combat runtime state builder: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_build_initializes_runtime_fields(builder) -> void:
	var result: Dictionary = builder.build(_state())
	_assert_eq(result.get("status"), "ready", "valid CombatState must produce runtime state")
	var runtime_state := result.get("state", {}) as Dictionary
	var fighters := runtime_state.get("fighters", []) as Array
	for raw_fighter in fighters:
		var fighter := raw_fighter as Dictionary
		var stats := fighter.get("stats", {}) as Dictionary
		_assert_eq(fighter.get("current_pv"), float(stats.get("PV", 0)), "current_pv starts from max PV")
		_assert_eq(fighter.get("vulnerable"), false, "fighters start non-vulnerable")


func _test_invalid_state_is_rejected(builder) -> void:
	var state := _state()
	(state.get("fighters", []) as Array)[0]["stamina"] = -1
	var result: Dictionary = builder.build(state)
	_assert_eq(result.get("status"), "invalid_state", "negative Stamina must fail closed")
	_assert_true(_contains_error(result.get("errors", []), "stamina cannot be negative"), "negative Stamina error must be explicit")


func _test_runtime_validation(builder) -> void:
	var runtime_state := (builder.build(_state()).get("state", {}) as Dictionary)
	_assert_eq(builder.validate_runtime_state(runtime_state), [], "fresh runtime state must validate")
	var fighter := (runtime_state.get("fighters", []) as Array)[0] as Dictionary
	fighter["vulnerable"] = "yes"
	_assert_true(_contains_error(builder.validate_runtime_state(runtime_state), "vulnerable must be bool"), "vulnerability state type must be protected")


func _test_ko_threshold(builder) -> void:
	var fighter := {"current_pv": 1}
	_assert_eq(builder.is_knocked_out(fighter), false, "positive current_pv is not KO")
	fighter["current_pv"] = 0
	_assert_eq(builder.is_knocked_out(fighter), true, "zero current_pv is KO")
	fighter["current_pv"] = -5
	_assert_eq(builder.is_knocked_out(fighter), true, "negative current_pv remains KO")


func _test_copy_isolation(builder) -> void:
	var source := _state()
	var source_before := source.duplicate(true)
	var runtime_state := builder.build(source).get("state", {}) as Dictionary
	var fighter := (runtime_state.get("fighters", []) as Array)[0] as Dictionary
	fighter["current_pv"] = 0
	fighter["vulnerable"] = true
	_assert_eq(source, source_before, "runtime preparation must not mutate canonical input")


func _state() -> Dictionary:
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


func _contains_error(errors_value: Variant, fragment: String) -> bool:
	if errors_value is not Array:
		return false
	for raw_error in errors_value as Array:
		if str(raw_error).contains(fragment):
			return true
	return false


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
