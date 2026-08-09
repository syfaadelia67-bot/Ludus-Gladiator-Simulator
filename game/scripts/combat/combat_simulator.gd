extends RefCounted

const CombatAccuracyResolverScript = preload("res://scripts/combat/combat_accuracy_resolver.gd")
const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatDamageResolverScript = preload("res://scripts/combat/combat_damage_resolver.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")
const CombatResolutionOrderBoundaryScript = preload(
	"res://scripts/combat/combat_resolution_order_boundary.gd"
)
const CombatResolutionReadinessScript = preload(
	"res://scripts/combat/combat_resolution_readiness.gd"
)
const CombatRulesD5D9ContractScript = preload("res://scripts/combat/combat_rules_d5_d9_contract.gd")
const CombatRuntimeStateBuilderScript = preload(
	"res://scripts/combat/combat_runtime_state_builder.gd"
)
const CombatStaminaResolverScript = preload("res://scripts/combat/combat_stamina_resolver.gd")
const CombatTargetResolverScript = preload("res://scripts/combat/combat_target_resolver.gd")

const PENDING_REASON := "combat_resolution_rules_not_frozen"
const NEXT_BLOCKER_ID := "defensive_action_effects"

var _accuracy_resolver = CombatAccuracyResolverScript.new()
var _combat_contract = CombatContractScript.new()
var _damage_resolver = CombatDamageResolverScript.new()
var _policy_contract = CombatPolicyContractScript.new()
var _resolution_order = CombatResolutionOrderBoundaryScript.new()
var _resolution_readiness = CombatResolutionReadinessScript.new()
var _d5_d9_contract = CombatRulesD5D9ContractScript.new()
var _runtime_state_builder = CombatRuntimeStateBuilderScript.new()
var _stamina_resolver = CombatStaminaResolverScript.new()
var _target_resolver = CombatTargetResolverScript.new()


func resolve_intent(state: Dictionary, desired_action: Dictionary) -> Dictionary:
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected_result("invalid_state", state_errors, state, desired_action)

	var policy_errors: Array[String] = _policy_contract.validate_desired_action(
		state, desired_action
	)
	if not policy_errors.is_empty():
		return _rejected_result("invalid_desired_action", policy_errors, state, desired_action)

	var target_inspection: Dictionary = (
		_target_resolver
		. inspect_action_targets(
			state,
			str(desired_action.get("actor_id", "")),
			str(desired_action.get("action_id", "")),
		)
	)
	if target_inspection.get("status") != "ready":
		var target_errors := target_inspection.get("errors", []) as Array
		if target_errors.is_empty():
			target_errors = ["Frozen D1 target resolution did not return a ready result"]
		return _rejected_result("invalid_target_context", target_errors, state, desired_action)

	var runtime_state_result: Dictionary = _runtime_state_builder.build(state)
	if runtime_state_result.get("status") != "ready":
		var runtime_errors := runtime_state_result.get("errors", []) as Array
		return _rejected_result("invalid_runtime_state", runtime_errors, state, desired_action)

	return {
		"ok": false,
		"pending": true,
		"reason": PENDING_REASON,
		"errors": [],
		"blocking_requirement": NEXT_BLOCKER_ID,
		"blocking_context":
		{
			"resolved_target_context": target_inspection.duplicate(true),
			"resolution_order_contract": _resolution_order.get_contract_status().duplicate(true),
			"damage_contract": _damage_resolver.get_contract().duplicate(true),
			"stamina_contract": _stamina_resolver.get_contract().duplicate(true),
			"accuracy_contract": _accuracy_resolver.get_contract().duplicate(true),
			"d5_d9_contracts": _d5_d9_contract.get_contracts(),
			"runtime_state_preview":
			(runtime_state_result.get("state", {}) as Dictionary).duplicate(true),
		},
		"frozen_requirements": _resolution_readiness.get_frozen_requirements(),
		"pending_requirements": _resolution_readiness.get_pending_requirements(),
		"conditional_requirements": _resolution_readiness.get_conditional_requirements(),
		"state": state.duplicate(true),
		"desired_action": desired_action.duplicate(true),
	}


func _rejected_result(
	reason: String, errors: Array[String], state: Dictionary, desired_action: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"pending": false,
		"reason": reason,
		"errors": errors.duplicate(),
		"blocking_requirement": "",
		"blocking_context": {},
		"frozen_requirements": [],
		"pending_requirements": [],
		"conditional_requirements": [],
		"state": state.duplicate(true),
		"desired_action": desired_action.duplicate(true),
	}
