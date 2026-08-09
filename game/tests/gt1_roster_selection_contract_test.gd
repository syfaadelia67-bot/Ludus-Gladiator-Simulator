extends SceneTree

const SelectionContractScript = preload("res://scripts/combat/gt1_roster_selection_contract.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	DataRepository.load_all()
	var contract = SelectionContractScript.new()
	_test_month_13(contract)
	_test_month_16(contract)
	_test_month_16_beast_readiness(contract)
	_test_month_20(contract)
	_test_unavailable_and_duplicate(contract)
	_test_frozen_contract(contract)
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


func _test_month_16_beast_readiness(contract) -> void:
	var readiness: Dictionary = contract.get_month_16_beast_readiness(false)
	_assert_true(
		readiness.get("status") == "blocked",
		"month XVI beast selection must remain blocked until canonical stats and adapter exist",
	)
	_assert_true(
		readiness.get("human_selection_ready") == true,
		"month XVI human selection must remain available while beast support is blocked",
	)
	_assert_true(
		readiness.get("beast_selection_ready") == false,
		"month XVI must not claim beast runtime readiness from allows_beasts alone",
	)
	_assert_true(
		readiness.get("invent_stats_allowed") == false,
		"month XVI must forbid invented beast combat stats",
	)


func _test_month_20(contract) -> void:
	var available: Array[String] = ["a", "b", "c", "d"]
	_assert_empty(
		contract.validate_selection(20, [["a", "b"], ["a", "b"], ["a", "c"]], available),
		"month XX must allow one unilateral substitution",
	)
	_assert_true(
		not (
			contract
			. validate_selection(20, [["a", "b"], ["a", "c"], ["a", "d"]], available)
			. is_empty()
		),
		"month XX must reject more than one substitution",
	)
	_assert_true(
		not (
			contract
			. validate_selection(20, [["a", "b"], ["c", "d"], ["c", "d"]], available)
			. is_empty()
		),
		"month XX substitution must keep exactly one fighter",
	)


func _test_unavailable_and_duplicate(contract) -> void:
	var available: Array[String] = ["a", "b"]
	_assert_true(
		not (
			contract
			. validate_selection(20, [["a", "a"], ["a", "b"], ["a", "b"]], available)
			. is_empty()
		),
		"same fighter cannot fill both 2v2 slots",
	)
	_assert_true(
		not (
			contract
			. validate_selection(13, [["missing"], ["missing"], ["missing"]], available)
			. is_empty()
		),
		"unavailable roster ids must be rejected",
	)


func _test_frozen_contract(contract) -> void:
	var frozen: Dictionary = contract.get_contract()
	_assert_true(
		frozen.get("month_16_frozen_design")
		== "one_available_gladiator_or_beast_per_independent_bout",
		"month XVI frozen design must retain gladiator-or-beast support",
	)
	_assert_true(
		frozen.get("month_16_current_selection")
		== "human_gladiators_only_until_beast_readiness",
		"month XVI current implementation must report human-only selection honestly",
	)
	_assert_true(
		frozen.get("month_16_beast_readiness") == "gt1_beast_readiness_contract",
		"month XVI selection must expose its beast readiness authority",
	)
	_assert_true(
		frozen.get("invent_beast_stats_allowed") == false,
		"roster selection must forbid invented beast stats",
	)


func _assert_empty(errors: Array, message: String) -> void:
	if not errors.is_empty():
		_failures.append("%s (errors=%s)" % [message, str(errors)])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
