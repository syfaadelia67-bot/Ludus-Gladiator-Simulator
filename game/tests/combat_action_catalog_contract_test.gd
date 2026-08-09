extends SceneTree

const CombatActionCatalogScript = preload("res://scripts/combat/combat_action_catalog.gd")
const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")

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
const PENDING_FIELDS: Array[String] = [
	"stat_scaling_status",
	"effect_status",
]

var _failures: Array[String] = []


func _initialize() -> void:
	var catalog = CombatActionCatalogScript.new()
	var contract = CombatContractScript.new()
	_test_exact_action_ids(catalog, contract)
	_test_d1_target_rules_are_frozen(catalog, contract)
	_test_d3_and_d6_metadata_are_frozen(catalog)
	_test_unfrozen_fields_stay_explicitly_pending(catalog)
	_test_catalog_reads_are_isolated(catalog)
	_test_unknown_action_is_rejected(catalog, contract)

	if _failures.is_empty():
		print("Combat action catalog contract: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_exact_action_ids(catalog, contract) -> void:
	_assert_eq(
		catalog.get_action_ids(), EXPECTED_ACTION_IDS, "catalog must expose six canonical actions"
	)
	_assert_eq(
		contract.get_action_ids(), EXPECTED_ACTION_IDS, "CombatContract must source catalog actions"
	)
	for action_id in EXPECTED_ACTION_IDS:
		_assert_true(
			contract.is_action_id_valid(action_id), "CombatContract must accept %s" % action_id
		)
		_assert_eq(
			contract.get_action_contract(action_id),
			catalog.get_action_contract(action_id),
			"CombatContract must source %s metadata from catalog" % action_id,
		)


func _test_d1_target_rules_are_frozen(catalog, contract) -> void:
	for action_id in ["light", "heavy"]:
		var action_contract: Dictionary = catalog.get_action_contract(action_id)
		_assert_eq(
			action_contract.get("target_rule_status"), "frozen", "%s D1 must be frozen" % action_id
		)
		_assert_eq(
			action_contract.get("target_required"), true, "%s must require target" % action_id
		)
		_assert_eq(
			action_contract.get("target_relationship"), "enemy", "%s must target enemy" % action_id
		)
		_assert_eq(
			action_contract.get("target_count"), 1, "%s must target exactly one enemy" % action_id
		)
	for action_id in ["block", "parry", "dodge", "reposition"]:
		var action_contract: Dictionary = catalog.get_action_contract(action_id)
		_assert_eq(
			action_contract.get("target_rule_status"), "frozen", "%s D1 must be frozen" % action_id
		)
		_assert_eq(
			action_contract.get("target_required"), false, "%s must not require target" % action_id
		)
		_assert_eq(
			action_contract.get("target_relationship"),
			"none",
			"%s has no explicit target" % action_id
		)
		_assert_eq(
			action_contract.get("target_count"), 0, "%s must accept zero targets" % action_id
		)
		_assert_eq(
			contract.get_action_contract(action_id).get("target_rule_status"),
			"frozen",
			"CombatContract must preserve frozen D1 metadata",
		)


func _test_d3_and_d6_metadata_are_frozen(catalog) -> void:
	for action_id in EXPECTED_ACTION_IDS:
		var action_contract: Dictionary = catalog.get_action_contract(action_id)
		_assert_eq(
			action_contract.get("stamina_cost_status"),
			"frozen",
			"%s D6 stamina cost status must be frozen" % action_id,
		)
		_assert_eq(
			action_contract.get("stamina_cost"),
			EXPECTED_STAMINA_COSTS[action_id],
			"%s must expose the frozen D6 stamina cost" % action_id,
		)
		_assert_eq(
			action_contract.get("resolution_timing_status"),
			"frozen",
			"%s D3 timing status must be frozen" % action_id,
		)
		_assert_eq(
			action_contract.get("resolution_phase"),
			EXPECTED_PHASES[action_id],
			"%s must expose its frozen D3 resolution phase" % action_id,
		)


func _test_unfrozen_fields_stay_explicitly_pending(catalog) -> void:
	var contracts: Array[Dictionary] = catalog.get_action_contracts()
	_assert_eq(
		contracts.size(), EXPECTED_ACTION_IDS.size(), "every action needs one catalog contract"
	)
	for action_contract in contracts:
		var action_id := str(action_contract.get("id", ""))
		_assert_true(
			EXPECTED_ACTION_IDS.has(action_id), "catalog contract must use canonical action id"
		)
		for field in PENDING_FIELDS:
			_assert_eq(
				action_contract.get(field),
				"pending",
				"%s must keep %s pending until design freeze" % [action_id, field],
			)


func _test_catalog_reads_are_isolated(catalog) -> void:
	var ids: Array[String] = catalog.get_action_ids()
	ids.clear()
	_assert_eq(
		catalog.get_action_ids(),
		EXPECTED_ACTION_IDS,
		"mutating returned ids must not alter catalog"
	)
	var light: Dictionary = catalog.get_action_contract("light")
	light["target_rule_status"] = "invented"
	light["target_relationship"] = "ally"
	light["stamina_cost"] = 999
	_assert_eq(
		catalog.get_action_contract("light").get("target_rule_status"),
		"frozen",
		"mutating returned action contract must not alter D1 status",
	)
	_assert_eq(
		catalog.get_action_contract("light").get("target_relationship"),
		"enemy",
		"mutating returned action contract must not alter D1 relationship",
	)
	_assert_eq(
		catalog.get_action_contract("light").get("stamina_cost"),
		3,
		"mutating returned action contract must not alter frozen D6 cost",
	)


func _test_unknown_action_is_rejected(catalog, contract) -> void:
	_assert_eq(
		catalog.get_action_contract("invented"), {}, "unknown action has no catalog contract"
	)
	_assert_true(not catalog.is_action_id_valid("invented"), "catalog must reject unknown action")
	_assert_true(
		not contract.is_action_id_valid("invented"), "CombatContract must reject unknown action"
	)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
