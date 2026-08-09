extends RefCounted

const FROZEN_STATUS := "frozen"
const PENDING_STATUS := "pending"

const CONTRACT := {
	"D5":
	{
		"id": "armor_and_vulnerability",
		"status": FROZEN_STATUS,
		"armor_source": "equipment_defense",
		"armor_is_separate_from_res": true,
		"body_part_armor_model": false,
		"vulnerability_authority": "combat_simulator",
		"vulnerability_is_explicit_state": true,
		"numeric_mitigation_status": PENDING_STATUS,
		"penetration_status": PENDING_STATUS,
	},
	"D6":
	{
		"id": "stamina",
		"status": FROZEN_STATUS,
		"resource_field": "stamina",
		"minimum": 0,
		"negative_values_allowed": false,
		"insufficient_stamina_behavior": "reject_action",
		"cost_table_status": PENDING_STATUS,
		"recovery_amount_status": PENDING_STATUS,
		"recovery_timing_status": PENDING_STATUS,
	},
	"D7":
	{
		"id": "accuracy_and_critical",
		"status": FROZEN_STATUS,
		"hit_rng_allowed": false,
		"critical_hits_enabled": false,
		"accuracy_resolution_owner": "combat_simulator",
		"accuracy_formula_status": PENDING_STATUS,
	},
	"D8":
	{
		"id": "stat_scaling",
		"status": FROZEN_STATUS,
		"roles":
		{
			"FUE": ["offensive_power"],
			"AGI": ["evasion", "reposition"],
			"TEC": ["accuracy", "parry"],
			"RES": ["mitigation", "block"],
			"PV": ["maximum_health"],
		},
		"legacy_endurance_substitution_allowed": false,
		"weights_status": PENDING_STATUS,
	},
	"D9":
	{
		"id": "ko_and_surrender",
		"status": FROZEN_STATUS,
		"runtime_health_field": "current_pv",
		"maximum_health_source": "stats.PV",
		"ko_condition": "current_pv_lte_zero",
		"ko_authority": "combat_simulator",
		"surrender_is_base_action": false,
		"surrender_rng_allowed": false,
		"surrender_rules_status": PENDING_STATUS,
	},
}


func get_contract(decision_id: String) -> Dictionary:
	if not CONTRACT.has(decision_id):
		return {}
	return (CONTRACT[decision_id] as Dictionary).duplicate(true)


func get_contracts() -> Dictionary:
	return CONTRACT.duplicate(true)


func get_pending_numeric_requirements() -> Array[String]:
	return [
		"armor_numeric_mitigation",
		"armor_penetration",
		"stamina_cost_table",
		"stamina_recovery_amount",
		"stamina_recovery_timing",
		"accuracy_formula",
		"stat_scaling_weights",
		"surrender_rules",
	]
