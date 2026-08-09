extends SceneTree

const SelectionContractScript = preload("res://scripts/combat/gt1_roster_selection_contract.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var contract = SelectionContractScript.new()
	_test_month_13(contract)
	_test_month_16(contract)
	_test_month_20(contract)
	_test_unavailable_and_duplicate(contract)
	if _failures.is_empty():
		print("GT I roster selection contract: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_month_13(contract) -> void:
	var available: Array[String] = ["a", "b", "c"]
	_assert_empty(
		contract.validate_selection(13, [["a"], ["a"], ["a"]], available),
		"month XIII must allow same gladiator across all three bouts",
	)
	_assert_true(
		not contract.validate_selection(13, [["a"], ["b"], ["a"]], available).is_empty(),
		"month XIII must reject changing the player gladiator",
	)


func _test_month_16(contract) -> void:
	var available: Array[String] = ["a", "b", "c"]
	_assert_empty(
		contract.validate_selection(16, [["a"], ["b"], ["c"]], available),
		"month XVI must allow independent one-gladiator selections",
	)


func _test_month_20(contract) -> void:
	var available: Array[String] = ["a", "b", "c", "d"]
	_assert_empty(
		contract.validate_selection(20, [["a", "b"], ["a", "b"], ["a", "c"]], available),
		"month XX must allow one unilateral substitution",
	)
	_assert_true(
		not contract.validate_selection(20, [["a", "b"], ["a", "c"], ["a", "d"]], available).is_empty(),
		"month XX must reject more than one substitution",
	)
	_assert_true(
		not contract.validate_selection(20, [["a", "b"], ["c", "d"], ["c", "d"]], available).is_empty(),
		"month XX substitution must keep exactly one fighter",
	)


func _test_unavailable_and_duplicate(contract) -> void:
	var available: Array[String] = ["a", "b"]
	_assert_true(
		not contract.validate_selection(20, [["a", "a"], ["a", "b"], ["a", "b"]], available).is_empty(),
		"same fighter cannot fill both 2v2 slots",
	)
	_assert_true(
		not contract.validate_selection(13, [["missing"], ["missing"], ["missing"]], available).is_empty(),
		"unavailable roster ids must be rejected",
	)


func _assert_empty(errors: Array, message: String) -> void:
	if not errors.is_empty():
		_failures.append("%s (errors=%s)" % [message, str(errors)])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
