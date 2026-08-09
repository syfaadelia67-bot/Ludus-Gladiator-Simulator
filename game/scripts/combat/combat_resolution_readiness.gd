extends RefCounted

const FROZEN_REQUIREMENTS: Array[String] = [
	"target_rules",
	"resolution_order",
	"damage_and_mitigation",
	"armor_numeric_mitigation",
	"armor_penetration_disabled_v1",
	"armor_and_vulnerability_structure",
	"stamina_structure",
	"stamina_cost_table",
	"stamina_recovery_amount",
	"stamina_recovery_timing",
	"accuracy_and_critical_structure",
	"stat_scaling_roles",
	"ko_structure",
]

const REQUIRED_DECISIONS: Array[String] = [
	"accuracy_formula",
	"stat_scaling_weights",
	"surrender_rules",
	"carryover",
]

const CONDITIONAL_DECISIONS: Array[String] = [
	"position_and_distance_model",
]


func get_frozen_requirements() -> Array[String]:
	return FROZEN_REQUIREMENTS.duplicate()


func get_pending_requirements() -> Array[String]:
	return REQUIRED_DECISIONS.duplicate()


func get_conditional_requirements() -> Array[String]:
	return CONDITIONAL_DECISIONS.duplicate()


func get_status() -> Dictionary:
	return {
		"frozen": false,
		"frozen_requirements": get_frozen_requirements(),
		"pending_requirements": get_pending_requirements(),
		"conditional_requirements": get_conditional_requirements(),
	}
