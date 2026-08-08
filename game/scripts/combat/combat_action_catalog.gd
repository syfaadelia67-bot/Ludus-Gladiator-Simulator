extends RefCounted

const PENDING_STATUS := "pending"
const ACTION_IDS: Array[String] = [
	"light",
	"heavy",
	"block",
	"parry",
	"dodge",
	"reposition",
]

const ACTION_CONTRACTS := {
	"light": {
		"id": "light",
		"target_rule_status": PENDING_STATUS,
		"stamina_cost_status": PENDING_STATUS,
		"resolution_timing_status": PENDING_STATUS,
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"heavy": {
		"id": "heavy",
		"target_rule_status": PENDING_STATUS,
		"stamina_cost_status": PENDING_STATUS,
		"resolution_timing_status": PENDING_STATUS,
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"block": {
		"id": "block",
		"target_rule_status": PENDING_STATUS,
		"stamina_cost_status": PENDING_STATUS,
		"resolution_timing_status": PENDING_STATUS,
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"parry": {
		"id": "parry",
		"target_rule_status": PENDING_STATUS,
		"stamina_cost_status": PENDING_STATUS,
		"resolution_timing_status": PENDING_STATUS,
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"dodge": {
		"id": "dodge",
		"target_rule_status": PENDING_STATUS,
		"stamina_cost_status": PENDING_STATUS,
		"resolution_timing_status": PENDING_STATUS,
		"stat_scaling_status": PENDING_STATUS,
		"effect_status": PENDING_STATUS,
	},
	"reposition": {
		"id": "reposition",
		"target_rule_status": PENDING_STATUS,
		"stamina_cost_status": PENDING_STATUS,
		"resolution_timing_status": PENDING_STATUS,
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
