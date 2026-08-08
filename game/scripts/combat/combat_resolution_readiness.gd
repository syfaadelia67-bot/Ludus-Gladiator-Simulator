extends RefCounted

const REQUIRED_DECISIONS: Array[String] = [
	"target_rules",
	"resolution_order",
	"damage_and_mitigation",
	"armor_and_vulnerability",
	"stamina_costs",
	"accuracy_and_critical",
	"stat_scaling",
	"ko_and_surrender",
	"carryover",
]

const CONDITIONAL_DECISIONS: Array[String] = [
	"position_and_distance_model",
]


func get_pending_requirements() -> Array[String]:
	return REQUIRED_DECISIONS.duplicate()


func get_conditional_requirements() -> Array[String]:
	return CONDITIONAL_DECISIONS.duplicate()


func get_status() -> Dictionary:
	return {
		"frozen": false,
		"pending_requirements": get_pending_requirements(),
		"conditional_requirements": get_conditional_requirements(),
	}
