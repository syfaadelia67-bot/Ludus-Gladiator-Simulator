extends SceneTree

const CombatExchangeCoordinatorScript = preload(
	"res://scripts/combat/combat_exchange_coordinator.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	_test_collects_one_intent_per_fighter()
	_test_duplicate_actor_is_rejected()
	_test_invalid_intent_is_rejected()
	_test_input_isolation()

	if _failures.is_empty():
		print("Combat exchange coordinator: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_collects_one_intent_per_fighter() -> void:
	var coordinator = CombatExchangeCoordinatorScript.new()
	var session: Dictionary = coordinator.start_exchange(_state())
	_assert_eq(session.get("status"), "collecting", "exchange must start collecting")
	_assert_eq(session.get("required_actor_ids"), ["a", "b"], "actor ids must serialize deterministically")
	_assert_eq(session.get("missing_actor_ids"), ["a", "b"], "both fighters must submit")

	var after_a: Dictionary = coordinator.submit_intent(
		session, {"actor_id": "a", "action_id": "light", "target_id": "b"}
	)
	_assert_eq(after_a.get("status"), "collecting", "one intent must not resolve a 1v1")
	_assert_eq(after_a.get("missing_actor_ids"), ["b"], "only b should remain missing")

	var after_b: Dictionary = coordinator.submit_intent(
		after_a, {"actor_id": "b", "action_id": "block"}
	)
	_assert_eq(after_b.get("status"), "resolved", "second valid intent must resolve exchange")
	_assert_eq(after_b.get("missing_actor_ids"), [], "resolved exchange has no missing fighters")
	var exchange_result := after_b.get("exchange_result", {}) as Dictionary
	_assert_eq(exchange_result.get("status"), "resolved", "coordinator must delegate to simulator")
	_assert_true(
		(exchange_result.get("attack_results", []) as Array).size() == 1,
		"light versus block must produce one attack result",
	)
	var contract: Dictionary = coordinator.get_contract()
	_assert_eq(contract.get("authority"), "combat_simulator", "coordinator must not own outcomes")
	_assert_eq(contract.get("default_action_allowed"), false, "coordinator must never invent defaults")
	_assert_eq(
		contract.get("serialization_order_is_priority"),
		false,
		"actor-id ordering must never become initiative",
	)


func _test_duplicate_actor_is_rejected() -> void:
	var coordinator = CombatExchangeCoordinatorScript.new()
	var session: Dictionary = coordinator.start_exchange(_state())
	session = coordinator.submit_intent(
		session, {"actor_id": "a", "action_id": "light", "target_id": "b"}
	)
	var duplicate: Dictionary = coordinator.submit_intent(
		session, {"actor_id": "a", "action_id": "heavy", "target_id": "b"}
	)
	_assert_eq(duplicate.get("status"), "rejected", "duplicate actor intent must fail closed")
	_assert_eq(duplicate.get("reason"), "duplicate_actor_intent", "duplicate reason must be explicit")


func _test_invalid_intent_is_rejected() -> void:
	var coordinator = CombatExchangeCoordinatorScript.new()
	var session: Dictionary = coordinator.start_exchange(_state())
	var invalid: Dictionary = coordinator.submit_intent(
		session, {"actor_id": "a", "action_id": "block", "target_id": "b"}
	)
	_assert_eq(invalid.get("status"), "rejected", "invalid D1 target must stop before simulation")
	_assert_eq(invalid.get("reason"), "invalid_desired_action", "policy rejection must be preserved")


func _test_input_isolation() -> void:
	var coordinator = CombatExchangeCoordinatorScript.new()
	var state := _state()
	var state_before := state.duplicate(true)
	var intent := {"actor_id": "a", "action_id": "dodge"}
	var intent_before := intent.duplicate(true)
	var session: Dictionary = coordinator.start_exchange(state)
	var next: Dictionary = coordinator.submit_intent(session, intent)
	_assert_eq(state, state_before, "coordinator must not mutate source state")
	_assert_eq(intent, intent_before, "coordinator must not mutate submitted intent")
	var stored := next.get("intents_by_actor", {}) as Dictionary
	(stored.get("a", {}) as Dictionary)["action_id"] = "heavy"
	_assert_eq(intent, intent_before, "returned session must be isolated from caller intent")


func _state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter("a", "alpha"),
			_fighter("b", "beta"),
		],
	}


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 20},
		"stamina": 10,
		"equipment": {"power": 12, "defense": 0},
	}


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
