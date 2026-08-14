extends SceneTree

const CombatCarryoverResolverScript = preload("res://scripts/combat/combat_carryover_resolver.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_carries_pv_and_stamina_for_same_fighter_id()
	_test_resets_transient_vulnerability()
	_test_new_opponent_starts_fresh()
	_test_contract_forbids_free_restore_between_consecutive_fights()

	if _failures.is_empty():
		print("Combat carryover resolver: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_carries_pv_and_stamina_for_same_fighter_id() -> void:
	var resolver = CombatCarryoverResolverScript.new()
	var previous := _runtime_state("a", "b")
	var previous_a := (previous["fighters"] as Array)[0] as Dictionary
	previous_a["current_pv"] = 6
	previous_a["stamina"] = 4
	var result: Dictionary = resolver.prepare_consecutive_fight(previous, _base_state("a", "c"))
	_assert_eq(result.get("status"), "ready", "valid consecutive fight must prepare")
	var carried_a: Dictionary = _fighter_by_id(result.get("state", {}) as Dictionary, "a")
	_assert_eq(carried_a.get("current_pv"), 6.0, "same fighter must carry current PV")
	_assert_eq(carried_a.get("stamina"), 4.0, "same fighter must carry Stamina")
	_assert_true(
		(result.get("carried_fighter_ids", []) as Array).has("a"),
		"carried fighter id must be exposed"
	)


func _test_resets_transient_vulnerability() -> void:
	var resolver = CombatCarryoverResolverScript.new()
	var previous := _runtime_state("a", "b")
	var previous_a := (previous["fighters"] as Array)[0] as Dictionary
	previous_a["vulnerable"] = true
	var result: Dictionary = resolver.prepare_consecutive_fight(previous, _base_state("a", "c"))
	var carried_a: Dictionary = _fighter_by_id(result.get("state", {}) as Dictionary, "a")
	_assert_eq(
		carried_a.get("vulnerable"), false, "between-fight transient vulnerability must reset"
	)


func _test_new_opponent_starts_fresh() -> void:
	var resolver = CombatCarryoverResolverScript.new()
	var previous := _runtime_state("a", "b")
	var result: Dictionary = resolver.prepare_consecutive_fight(previous, _base_state("a", "c"))
	var new_opponent: Dictionary = _fighter_by_id(result.get("state", {}) as Dictionary, "c")
	_assert_eq(new_opponent.get("current_pv"), 10.0, "new opponent must start at full canonical PV")
	_assert_eq(new_opponent.get("stamina"), 10, "new opponent must keep base Stamina")
	_assert_true(
		not (result.get("carried_fighter_ids", []) as Array).has("c"),
		"new opponent is not carryover"
	)


func _test_contract_forbids_free_restore_between_consecutive_fights() -> void:
	var resolver = CombatCarryoverResolverScript.new()
	var contract: Dictionary = resolver.get_contract()
	_assert_eq(contract.get("status"), "frozen", "D10 contract must be frozen")
	_assert_eq(contract.get("full_heal_between_consecutive_fights"), false, "no free GT heal")
	_assert_eq(
		contract.get("full_stamina_restore_between_consecutive_fights"),
		false,
		"no free GT stamina reset"
	)


func _base_state(first_id: String, second_id: String) -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter(first_id, "alpha"),
			_fighter(second_id, "beta"),
		],
	}


func _runtime_state(first_id: String, second_id: String) -> Dictionary:
	var state := _base_state(first_id, second_id)
	for raw_fighter in state["fighters"] as Array:
		var fighter := raw_fighter as Dictionary
		fighter["current_pv"] = 10
		fighter["stamina_capacity"] = 10
		fighter["vulnerable"] = false
	return state


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 10},
		"stamina": 10,
	}


func _fighter_by_id(state: Dictionary, fighter_id: String) -> Dictionary:
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("id", "")) == fighter_id:
			return fighter.duplicate(true)
	return {}


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
