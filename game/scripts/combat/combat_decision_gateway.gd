extends RefCounted

const LimboAIPolicyRunnerScript = preload("res://scripts/combat/limboai_policy_runner.gd")
const CombatSimulatorScript = preload("res://scripts/combat/combat_simulator.gd")

var _policy_runner = LimboAIPolicyRunnerScript.new()
var _simulator = CombatSimulatorScript.new()


func resolve_proposal(
	state: Dictionary,
	actor_id: String,
	policy_proposal: Dictionary,
	agent: Node,
	instance_owner: Node
) -> Dictionary:
	var policy_result: Dictionary = _policy_runner.evaluate_proposal(
		state, actor_id, policy_proposal, agent, instance_owner
	)
	if policy_result.get("status") != "ready":
		return _policy_rejected(policy_result)

	var desired_action := (policy_result.get("desired_action", {}) as Dictionary).duplicate(true)
	var simulation_result: Dictionary = _simulator.resolve_intent(state, desired_action)
	return _simulation_result(policy_result, desired_action, simulation_result)


func _policy_rejected(policy_result: Dictionary) -> Dictionary:
	return {
		"status": "policy_rejected",
		"pending": false,
		"provider": "limboai",
		"reason": str(policy_result.get("status", "policy_rejected")),
		"pending_requirements": [],
		"conditional_requirements": [],
		"desired_action": {},
		"policy": policy_result.duplicate(true),
		"simulation": {},
	}


func _simulation_result(
	policy_result: Dictionary, desired_action: Dictionary, simulation_result: Dictionary
) -> Dictionary:
	var status := "simulation_rejected"
	if bool(simulation_result.get("pending", false)):
		status = "pending"
	elif bool(simulation_result.get("ok", false)):
		status = "resolved"
	return {
		"status": status,
		"pending": bool(simulation_result.get("pending", false)),
		"provider": "limboai",
		"reason": str(simulation_result.get("reason", "")),
		"pending_requirements": _duplicate_array(
			simulation_result.get("pending_requirements", [])
		),
		"conditional_requirements": _duplicate_array(
			simulation_result.get("conditional_requirements", [])
		),
		"desired_action": desired_action.duplicate(true),
		"policy": policy_result.duplicate(true),
		"simulation": simulation_result.duplicate(true),
	}


func _duplicate_array(value: Variant) -> Array:
	if value is not Array:
		return []
	return (value as Array).duplicate(true)
