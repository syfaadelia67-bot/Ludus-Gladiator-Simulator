extends SceneTree

const CombatRulesD5D9ContractScript = preload("res://scripts/combat/combat_rules_d5_d9_contract.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var contract = CombatRulesD5D9ContractScript.new()
	_test_d5(contract)
	_test_d6(contract)
	_test_d7(contract)
	_test_d8(contract)
	_test_d9(contract)
	_test_copy_isolation(contract)

	if _failures.is_empty():
		print("Combat D5-D9 structural contract: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_d5(contract) -> void:
	var d5: Dictionary = contract.get_contract("D5")
	_assert_eq(d5.get("status"), "frozen", "D5 structure must be frozen")
	_assert_eq(
		d5.get("armor_source"),
		"equipment_defense",
		"armor must come from canonical equipment defense"
	)
	_assert_eq(
		d5.get("armor_is_separate_from_res"), true, "armor and RES must remain separate inputs"
	)
	_assert_eq(d5.get("body_part_armor_model"), false, "V1 must not invent body-part armor")
	_assert_eq(
		d5.get("vulnerability_authority"), "combat_simulator", "simulator owns vulnerability state"
	)
	_assert_eq(d5.get("numeric_mitigation_status"), "frozen", "D4 freezes armor mitigation")
	_assert_eq(d5.get("penetration_status"), "disabled_v1", "V1 penetration stays disabled")


func _test_d6(contract) -> void:
	var d6: Dictionary = contract.get_contract("D6")
	_assert_eq(d6.get("status"), "frozen", "D6 structure must be frozen")
	_assert_eq(d6.get("resource_field"), "stamina", "Stamina field must remain canonical")
	_assert_eq(d6.get("capacity_field"), "stamina_capacity", "D6 needs an explicit runtime cap")
	_assert_eq(d6.get("minimum"), 0, "Stamina cannot go below zero")
	_assert_eq(d6.get("negative_values_allowed"), false, "negative Stamina must be forbidden")
	_assert_eq(
		d6.get("insufficient_stamina_behavior"),
		"reject_action",
		"insufficient Stamina must fail closed"
	)
	_assert_eq(
		d6.get("action_costs"),
		{"light": 3, "heavy": 5, "block": 2, "parry": 3, "dodge": 4, "reposition": 2},
		"D6 action costs must remain frozen"
	)
	_assert_eq(d6.get("recovery_amount"), 2, "D6 recovery amount must remain frozen")
	_assert_eq(d6.get("recovery_timing"), "end_exchange", "recovery happens once per exchange")
	_assert_eq(d6.get("cost_table_status"), "frozen", "cost table must be frozen")
	_assert_eq(d6.get("recovery_amount_status"), "frozen", "recovery amount must be frozen")
	_assert_eq(d6.get("recovery_timing_status"), "frozen", "recovery timing must be frozen")


func _test_d7(contract) -> void:
	var d7: Dictionary = contract.get_contract("D7")
	_assert_eq(d7.get("status"), "frozen", "D7 structure must be frozen")
	_assert_eq(d7.get("hit_rng_allowed"), false, "V1 hit resolution must not use RNG")
	_assert_eq(d7.get("critical_hits_enabled"), false, "V1 critical hits must be disabled")
	_assert_eq(
		d7.get("accuracy_resolution_owner"), "combat_simulator", "simulator must own accuracy"
	)
	_assert_eq(d7.get("accuracy_formula_status"), "pending", "accuracy formula stays pending")


func _test_d8(contract) -> void:
	var d8: Dictionary = contract.get_contract("D8")
	var roles := d8.get("roles", {}) as Dictionary
	_assert_eq(d8.get("status"), "frozen", "D8 role map must be frozen")
	_assert_eq(roles.get("FUE"), ["offensive_power"], "FUE role must stay offensive")
	_assert_eq(roles.get("AGI"), ["evasion", "reposition"], "AGI roles must stay mobility/evasion")
	_assert_eq(roles.get("TEC"), ["accuracy", "parry"], "TEC roles must stay precision/parry")
	_assert_eq(roles.get("RES"), ["mitigation", "block"], "RES roles must stay mitigation/block")
	_assert_eq(roles.get("PV"), ["maximum_health"], "PV must be maximum health")
	_assert_eq(
		d8.get("legacy_endurance_substitution_allowed"),
		false,
		"endurance must not silently become RES"
	)
	_assert_eq(d8.get("weights_status"), "pending", "exact stat weights must remain pending")


func _test_d9(contract) -> void:
	var d9: Dictionary = contract.get_contract("D9")
	_assert_eq(d9.get("status"), "frozen", "D9 structure must be frozen")
	_assert_eq(
		d9.get("runtime_health_field"), "current_pv", "runtime health must be distinct from max PV"
	)
	_assert_eq(d9.get("maximum_health_source"), "stats.PV", "max health comes from canonical PV")
	_assert_eq(d9.get("ko_condition"), "current_pv_lte_zero", "KO threshold must be explicit")
	_assert_eq(d9.get("ko_authority"), "combat_simulator", "simulator owns KO")
	_assert_eq(
		d9.get("surrender_is_base_action"), false, "surrender must not become a seventh base action"
	)
	_assert_eq(
		d9.get("surrender_rng_allowed"),
		false,
		"legacy probabilistic surrender must stay quarantined"
	)
	_assert_eq(d9.get("surrender_rules_status"), "pending", "surrender eligibility remains pending")


func _test_copy_isolation(contract) -> void:
	var first: Dictionary = contract.get_contracts()
	var second: Dictionary = contract.get_contracts()
	(first["D8"] as Dictionary)["status"] = "mutated"
	_assert_eq(
		(second["D8"] as Dictionary).get("status"), "frozen", "contract copies must be isolated"
	)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
