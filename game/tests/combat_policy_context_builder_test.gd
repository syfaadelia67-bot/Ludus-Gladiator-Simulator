extends SceneTree

const CombatPolicyContextBuilderScript = preload(
	"res://scripts/combat/combat_policy_context_builder.gd"
)

const EXPECTED_ACTION_IDS: Array[String] = [
	"light",
	"heavy",
	"block",
	"parry",
	"dodge",
	"reposition",
]
const EXPECTED_STAMINA_COSTS := {
	"light": 3,
	"heavy": 5,
	"block": 2,
	"parry": 3,
	"dodge": 4,
	"reposition": 2,
}
const EXPECTED_PHASES := {
	"light": "offense",
	"heavy": "offense",
	"block": "preparation",
	"parry": "preparation",
	"dodge": "preparation",
	"reposition": "preparation",
}
const PENDING_ACTION_FIELDS: Array[String] = [
	"stat_scaling_status",
	"effect_status",
]

var _failures: Array[String] = []


func _initialize() -> void:
	var builder = CombatPolicyContextBuilderScript.new()
	_test_1v1_context(builder)
	_test_2v2_relationships(builder)
	_test_1v2_relationships(builder)
	_test_invalid_inputs(builder)

	if _failures.is_empty():
		print("Combat policy context builder: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_1v1_context(builder) -> void:
	var state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	var result: Dictionary = builder.build_context(state, "a")
	_assert_eq(result.get("status"), "ready", "1v1 context must build")
	var context := result.get("context", {}) as Dictionary
	_assert_eq(context.get("format"), "1v1", "context must expose combat format")
	_assert_eq((context.get("actor") as Dictionary).get("id"), "a", "context must expose actor")
	_assert_eq((context.get("allies") as Array).size(), 0, "1v1 actor has no allies")
	_assert_eq((context.get("enemies") as Array).size(), 1, "1v1 actor has one enemy")
	_assert_eq(
		context.get("available_action_ids"),
		EXPECTED_ACTION_IDS,
		"context must expose the canonical action catalog",
	)
	_assert_action_contracts(context.get("action_contracts", []))
	var candidates := context.get("target_candidates") as Dictionary
	_assert_eq(candidates.get("allies"), [], "1v1 ally candidates must be empty")
	_assert_eq(candidates.get("enemies"), ["b"], "1v1 enemy candidates must expose opponent")
	var legal_targets := context.get("legal_targets", {}) as Dictionary
	_assert_eq(legal_targets.get("light"), ["b"], "light must expose enemy target")
	_assert_eq(legal_targets.get("heavy"), ["b"], "heavy must expose enemy target")
	for action_id in ["block", "parry", "dodge", "reposition"]:
		_assert_eq(
			legal_targets.get(action_id), [], "%s must expose no explicit targets" % action_id
		)
	var isolated_actor := context.get("actor") as Dictionary
	isolated_actor["stamina"] = 0
	_assert_eq(
		(state.get("fighters") as Array)[0].get("stamina"), 100, "actor view must be isolated"
	)
	var action_contracts := context.get("action_contracts") as Array
	var first_contract := action_contracts[0] as Dictionary
	first_contract["target_relationship"] = "invented"
	(legal_targets.get("light") as Array).clear()
	var rebuilt := builder.build_context(state, "a").get("context", {}) as Dictionary
	var rebuilt_contracts := rebuilt.get("action_contracts") as Array
	_assert_eq(
		(rebuilt_contracts[0] as Dictionary).get("target_relationship"),
		"enemy",
		"mutating policy target metadata must not alter canonical catalog",
	)
	_assert_eq(
		(rebuilt.get("legal_targets", {}) as Dictionary).get("light"),
		["b"],
		"mutating legal target view must not alter rebuilt context",
	)


func _test_2v2_relationships(builder) -> void:
	var state := _state(
		"2v2",
		[
			_fighter("a", "alpha"),
			_fighter("a2", "alpha"),
			_fighter("b", "beta"),
			_fighter("b2", "beta"),
		],
	)
	var context := builder.build_context(state, "a").get("context", {}) as Dictionary
	_assert_eq(_ids(context.get("allies") as Array), ["a2"], "2v2 must classify ally")
	_assert_eq(_ids(context.get("enemies") as Array), ["b", "b2"], "2v2 must classify enemies")
	var legal_targets := context.get("legal_targets", {}) as Dictionary
	_assert_eq(legal_targets.get("light"), ["b", "b2"], "2v2 light targets both enemies")
	_assert_eq(legal_targets.get("heavy"), ["b", "b2"], "2v2 heavy targets both enemies")


func _test_1v2_relationships(builder) -> void:
	var state := _state(
		"1v2",
		[
			_fighter("a", "alpha"),
			_fighter("b", "beta"),
			_fighter("b2", "beta"),
		],
	)
	var context := builder.build_context(state, "b").get("context", {}) as Dictionary
	_assert_eq(_ids(context.get("allies") as Array), ["b2"], "1v2 larger team must expose ally")
	_assert_eq(_ids(context.get("enemies") as Array), ["a"], "1v2 larger team must expose enemy")
	_assert_eq(
		(context.get("legal_targets", {}) as Dictionary).get("light"),
		["a"],
		"1v2 larger side may target solo enemy",
	)


func _test_invalid_inputs(builder) -> void:
	var valid_state := _state("1v1", [_fighter("a", "alpha"), _fighter("b", "beta")])
	_assert_eq(
		builder.build_context(valid_state, "missing").get("status"),
		"invalid_actor",
		"unknown actor must be rejected",
	)
	var invalid_state := valid_state.duplicate(true)
	invalid_state["format"] = "3v3"
	_assert_eq(
		builder.build_context(invalid_state, "a").get("status"),
		"invalid_state",
		"unsupported combat state must be rejected before policy perception",
	)


func _assert_action_contracts(value: Variant) -> void:
	_assert_true(value is Array, "context must expose action contracts")
	if value is not Array:
		return
	var contracts := value as Array
	_assert_eq(
		contracts.size(), EXPECTED_ACTION_IDS.size(), "context must expose six action contracts"
	)
	for index in range(contracts.size()):
		var action_contract := contracts[index] as Dictionary
		var action_id := EXPECTED_ACTION_IDS[index]
		_assert_eq(
			action_contract.get("id"),
			action_id,
			"action contract order must match canonical ids",
		)
		_assert_eq(
			action_contract.get("target_rule_status"),
			"frozen",
			"D1 target rules must be frozen in policy context",
		)
		_assert_eq(
			action_contract.get("stamina_cost_status"),
			"frozen",
			"D6 stamina cost must be frozen in policy context",
		)
		_assert_eq(
			action_contract.get("stamina_cost"),
			EXPECTED_STAMINA_COSTS[action_id],
			"policy context must expose exact D6 cost",
		)
		_assert_eq(
			action_contract.get("resolution_timing_status"),
			"frozen",
			"D3 timing must be frozen in policy context",
		)
		_assert_eq(
			action_contract.get("resolution_phase"),
			EXPECTED_PHASES[action_id],
			"policy context must expose exact D3 phase",
		)
		for field in PENDING_ACTION_FIELDS:
			_assert_eq(
				action_contract.get(field),
				"pending",
				"unfrozen action contract fields must stay pending",
			)


func _state(format_id: String, fighters: Array) -> Dictionary:
	return {"format": format_id, "fighters": fighters}


func _fighter(id: String, team: String) -> Dictionary:
	return {
		"id": id,
		"team": team,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"stamina": 100,
	}


func _ids(fighters: Array) -> Array[String]:
	var result: Array[String] = []
	for fighter in fighters:
		result.append(str((fighter as Dictionary).get("id", "")))
	return result


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
