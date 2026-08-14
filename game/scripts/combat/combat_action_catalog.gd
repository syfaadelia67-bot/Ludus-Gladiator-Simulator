extends RefCounted

const PENDING_STATUS := "pending"
const FROZEN_STATUS := "frozen"
const TARGET_RELATIONSHIP_ENEMY := "enemy"
const TARGET_RELATIONSHIP_NONE := "none"
const ACTION_IDS: Array[String] = [
	"light",
	"heavy",
	"block",
	"parry",
	"dodge",
	"reposition",
	"recover",
]
const STAMINA_COSTS := {
	"light": 3,
	"heavy": 5,
	"block": 2,
	"parry": 3,
	"dodge": 4,
	"reposition": 2,
	"recover": 0,
}
const RESOLUTION_PHASES := {
	"light": "offense",
	"heavy": "offense",
	"block": "preparation",
	"parry": "preparation",
	"dodge": "preparation",
	"reposition": "preparation",
	"recover": "preparation",
}

const ACTION_CONTRACTS := {
	"light":
	{
		"id": "light",
		"target_rule_status": FROZEN_STATUS,
		"target_required": true,
		"target_relationship": TARGET_RELATIONSHIP_ENEMY,
		"target_count": 1,
		"stamina_cost_status": FROZEN_STATUS,
		"stamina_cost": 3,
		"resolution_timing_status": FROZEN_STATUS,
		"resolution_phase": "offense",
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"heavy":
	{
		"id": "heavy",
		"target_rule_status": FROZEN_STATUS,
		"target_required": true,
		"target_relationship": TARGET_RELATIONSHIP_ENEMY,
		"target_count": 1,
		"stamina_cost_status": FROZEN_STATUS,
		"stamina_cost": 5,
		"resolution_timing_status": FROZEN_STATUS,
		"resolution_phase": "offense",
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"block":
	{
		"id": "block",
		"target_rule_status": FROZEN_STATUS,
		"target_required": false,
		"target_relationship": TARGET_RELATIONSHIP_NONE,
		"target_count": 0,
		"stamina_cost_status": FROZEN_STATUS,
		"stamina_cost": 2,
		"resolution_timing_status": FROZEN_STATUS,
		"resolution_phase": "preparation",
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"parry":
	{
		"id": "parry",
		"target_rule_status": FROZEN_STATUS,
		"target_required": false,
		"target_relationship": TARGET_RELATIONSHIP_NONE,
		"target_count": 0,
		"stamina_cost_status": FROZEN_STATUS,
		"stamina_cost": 3,
		"resolution_timing_status": FROZEN_STATUS,
		"resolution_phase": "preparation",
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"dodge":
	{
		"id": "dodge",
		"target_rule_status": FROZEN_STATUS,
		"target_required": false,
		"target_relationship": TARGET_RELATIONSHIP_NONE,
		"target_count": 0,
		"stamina_cost_status": FROZEN_STATUS,
		"stamina_cost": 4,
		"resolution_timing_status": FROZEN_STATUS,
		"resolution_phase": "preparation",
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"reposition":
	{
		"id": "reposition",
		"target_rule_status": FROZEN_STATUS,
		"target_required": false,
		"target_relationship": TARGET_RELATIONSHIP_NONE,
		"target_count": 0,
		"stamina_cost_status": FROZEN_STATUS,
		"stamina_cost": 2,
		"resolution_timing_status": FROZEN_STATUS,
		"resolution_phase": "preparation",
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"recover":
	{
		"id": "recover",
		"target_rule_status": FROZEN_STATUS,
		"target_required": false,
		"target_relationship": TARGET_RELATIONSHIP_NONE,
		"target_count": 0,
		"stamina_cost_status": FROZEN_STATUS,
		"stamina_cost": 0,
		"resolution_timing_status": FROZEN_STATUS,
		"resolution_phase": "preparation",
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
}


func is_action_id_valid(action_id: String) -> bool:
	return ACTION_CONTRACTS.has(action_id)


func get_action_ids() -> Array[String]:
	return ACTION_IDS.duplicate()


func get_action_contract(action_id: String) -> Dictionary:
	if not ACTION_CONTRACTS.has(action_id):
		return {}
	return (ACTION_CONTRACTS[action_id] as Dictionary).duplicate(true)


func get_action_contracts() -> Array[Dictionary]:
	var contracts: Array[Dictionary] = []
	for action_id in ACTION_IDS:
		contracts.append(get_action_contract(action_id))
	return contracts
