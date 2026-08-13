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
	_assert_eq(d5.get("armor_source"), "equipment_defense", "armor must come from equipment")
	_assert_eq(d5.get("armor_is_separate_from_res"), true, "armor and RES remain separate")
	_assert_eq(d5.get("body_part_armor_model"), false, "V1 must not invent body-part armor")
	_assert_eq(
		d5.get("vulnerability_authority"), "combat_simulator", "simulator owns vulnerability"
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
		"insufficient Stamina fails closed"
	)
	_assert_eq(
		d6.get("action_costs"),
		{
			"light": 3,
			"heavy": 5,
			"block": 2,
			"parry": 3,
			"dodge": 4,
			"reposition": 2,
			"recover": 0,
		},
		"D6 action costs must remain frozen",
	)
	_assert_eq(d6.get("recovery_amount"), 2, "D6 recovery amount must remain frozen")
	_assert_eq(d6.get("recovery_timing"), "end_exchange", "recovery happens once per exchange")
	_assert_eq(d6.get("recovery_action_id"), "recover", "D6 must expose a recovery turn")
	_assert_eq(
		d6.get("recovery_action_cost"), 0, "recovery turn must remain payable at zero stamina"
	)
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
	_assert_eq(d7.get("accuracy_formula_status"), "frozen", "D7 accuracy formula must be frozen")
	_assert_eq(d7.get("attacker_stat"), "TEC", "D7 attack score must use TEC")
	_assert_eq(d7.get("defender_stat"), "AGI", "D7 evasion score must use AGI")
	_assert_eq(d7.get("action_accuracy_modifiers"), {"light": 1.0, "heavy": 0.0}, "accuracy mods")
	_assert_eq(d7.get("hit_rule"), "attack_score_gte_evasion_score", "D7 hit rule deterministic")


func _test_d8(contract) -> void:
	var d8: Dictionary = contract.get_contract("D8")
	var roles := d8.get("roles", {}) as Dictionary
	var weights := d8.get("weights", {}) as Dictionary
	var modifiers := d8.get("flat_action_modifiers", {}) as Dictionary
	_assert_eq(d8.get("status"), "frozen", "D8 role map must be frozen")
	_assert_eq(roles.get("FUE"), ["offensive_power"], "FUE role must stay offensive")
	_assert_eq(roles.get("AGI"), ["evasion", "reposition"], "AGI roles must stay mobility/evasion")
	_assert_eq(roles.get("TEC"), ["accuracy", "parry"], "TEC roles must stay precision/parry")
	_assert_eq(roles.get("RES"), ["mitigation", "block"], "RES roles must stay mitigation/block")
	_assert_eq(roles.get("PV"), ["maximum_health"], "PV must be maximum health")
	_assert_eq(weights.get("FUE"), {"light_damage": 0.35, "heavy_damage": 0.50}, "FUE D4 weights")
	_assert_eq(weights.get("AGI"), {"base_evasion": 1.0}, "AGI evasion weight must match D7")
	_assert_eq(weights.get("TEC"), {"accuracy": 1.0, "parry": 1.0}, "TEC weights must match")
	_assert_eq(
		weights.get("RES"),
		{"damage_mitigation": 0.15, "block_reduction": 0.25},
		"RES weights must match D4/block",
	)
	_assert_eq(weights.get("PV"), {"maximum_health": 1.0}, "PV must remain 1:1 maximum health")
	_assert_eq(modifiers.get("dodge_evasion"), 2.0, "dodge flat modifier must stay frozen")
	_assert_eq(modifiers.get("reposition_evasion"), 1.0, "reposition modifier must stay frozen")
	_assert_eq(
		d8.get("legacy_endurance_substitution_allowed"), false, "endurance cannot replace RES"
	)
	_assert_eq(d8.get("weights_status"), "frozen", "exact stat weights must be frozen")


func _test_d9(contract) -> void:
	var d9: Dictionary = contract.get_contract("D9")
	_assert_eq(d9.get("status"), "frozen", "D9 structure must be frozen")
	_assert_eq(d9.get("runtime_health_field"), "current_pv", "runtime health must be current_pv")
	_assert_eq(d9.get("maximum_health_source"), "stats.PV", "max health comes from canonical PV")
	_assert_eq(d9.get("ko_condition"), "current_pv_lte_zero", "KO threshold must be explicit")
	_assert_eq(d9.get("ko_authority"), "combat_simulator", "simulator owns KO")
	_assert_eq(
		d9.get("combat_end_condition"), "team_elimination", "combat ends on team elimination"
	)
	_assert_eq(d9.get("double_ko_outcome"), "double_ko", "double KO must remain explicit")
	_assert_eq(d9.get("surrender_is_base_action"), false, "surrender is not a base action")
	_assert_eq(d9.get("surrender_rng_allowed"), false, "probabilistic surrender remains forbidden")
	_assert_eq(d9.get("automatic_surrender"), "disabled_v1", "automatic surrender is disabled V1")
	_assert_eq(d9.get("surrender_rules_status"), "frozen", "D9 surrender rule must be frozen")
	_assert_eq(
		contract.get_pending_numeric_requirements(), [], "D5-D9 must expose no pending rules"
	)


func _test_copy_isolation(contract) -> void:
	var first: Dictionary = contract.get_contracts()
	var second: Dictionary = contract.get_contracts()
	(first["D8"] as Dictionary)["status"] = "mutated"
	_assert_eq((second["D8"] as Dictionary).get("status"), "frozen", "contract copies isolated")


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
