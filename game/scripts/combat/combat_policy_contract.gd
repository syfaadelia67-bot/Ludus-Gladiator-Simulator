extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatFighterActionPolicyScript = preload(
	"res://scripts/combat/combat_fighter_action_policy.gd"
)
const CombatTargetResolverScript = preload("res://scripts/combat/combat_target_resolver.gd")
const CombatSkillRuntimeResolverScript = preload(
	"res://scripts/combat/combat_skill_runtime_resolver.gd"
)
const CombatSkillEffectResolverScript = preload(
	"res://scripts/combat/combat_skill_effect_resolver.gd"
)

var _combat_contract = CombatContractScript.new()
var _fighter_action_policy = CombatFighterActionPolicyScript.new()
var _target_resolver = CombatTargetResolverScript.new()
var _skill_runtime_resolver = CombatSkillRuntimeResolverScript.new()
var _skill_effect_resolver = CombatSkillEffectResolverScript.new()
var _skill_mechanics_by_id: Dictionary = {}


func set_skill_mechanics(entries: Array) -> void:
	_skill_mechanics_by_id.clear()
	for raw_entry in entries:
		if raw_entry is Dictionary:
			var entry := raw_entry as Dictionary
			var skill_id := str(entry.get("id", ""))
			if not skill_id.is_empty():
				_skill_mechanics_by_id[skill_id] = entry.duplicate(true)


func validate_desired_action(state: Dictionary, desired_action: Dictionary) -> Array[String]:
	var errors: Array[String] = _combat_contract.validate_state(state)
	if not errors.is_empty():
		return errors

	var actor_id := str(desired_action.get("actor_id", ""))
	var actor: Dictionary = {}
	if actor_id.is_empty():
		errors.append("Desired action is missing actor_id")
	else:
		actor = _find_fighter(state, actor_id)
		if actor.is_empty():
			errors.append("Desired action references unknown actor: %s" % actor_id)
	if not errors.is_empty():
		return errors

	var translated: Dictionary = _skill_runtime_resolver.resolve_desired_action(
		actor, desired_action, _skill_mechanics_by_id
	)
	if translated.get("status") != "ready":
		for raw_error in translated.get("errors", []) as Array:
			errors.append(str(raw_error))
		return errors
	var resolved_action := translated.get("desired_action", {}) as Dictionary
	var activation := translated.get("skill_activation", {}) as Dictionary
	if activation.is_empty():
		activation = _skill_effect_resolver.get_activation(resolved_action)
	var action_id := str(resolved_action.get("action_id", ""))

	if action_id.is_empty():
		errors.append("Desired action is missing action_id")
	elif not _combat_contract.is_action_id_valid(action_id):
		errors.append("Desired action uses unsupported action: %s" % action_id)
	elif not _fighter_action_policy.is_action_allowed(actor, action_id):
		errors.append("Desired action %s is not allowed for actor %s" % [action_id, actor_id])
	errors.append_array(_skill_effect_resolver.validate_intent(state, resolved_action))
	if not errors.is_empty():
		return errors

	if not activation.is_empty():
		errors.append_array(_validate_skill_targets(state, actor, resolved_action, activation))
		return errors
	_validate_base_targets(state, actor_id, action_id, resolved_action, errors)
	return errors


func resolve_desired_action(state: Dictionary, desired_action: Dictionary) -> Dictionary:
	var actor_id := str(desired_action.get("actor_id", ""))
	var actor := _find_fighter(state, actor_id)
	if actor.is_empty():
		return {
			"status": "rejected",
			"errors": ["Desired action references unknown actor: %s" % actor_id],
			"desired_action": {},
			"skill_activation": {},
		}
	return _skill_runtime_resolver.resolve_desired_action(
		actor, desired_action, _skill_mechanics_by_id
	)


func is_valid_desired_action(state: Dictionary, desired_action: Dictionary) -> bool:
	return validate_desired_action(state, desired_action).is_empty()


func _validate_base_targets(
	state: Dictionary,
	actor_id: String,
	action_id: String,
	resolved_action: Dictionary,
	errors: Array[String]
) -> void:
	var target_id := str(resolved_action.get("target_id", ""))
	var target_result: Dictionary = _target_resolver.inspect_action_targets(
		state, actor_id, action_id
	)
	if target_result.get("status") != "ready":
		errors.append(
			"Desired action target rules are unavailable: %s" % str(target_result.get("status", ""))
		)
		return
	var target_required := bool(target_result.get("target_required", false))
	var relationship := str(target_result.get("target_relationship", ""))
	var legal_targets := target_result.get("legal_targets", []) as Array
	if target_required:
		if target_id.is_empty():
			errors.append(
				"Desired action %s requires exactly one %s target" % [action_id, relationship]
			)
		elif not _fighter_exists(state, target_id):
			errors.append("Desired action references unknown target: %s" % target_id)
		elif not legal_targets.has(target_id):
			errors.append(
				(
					"Desired action %s target %s is not a legal %s target"
					% [action_id, target_id, relationship]
				)
			)
	elif not target_id.is_empty():
		errors.append("Desired action %s does not accept an explicit target" % action_id)


func _validate_skill_targets(
	state: Dictionary, actor: Dictionary, intent: Dictionary, activation: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	var mechanics := activation.get("mechanics", {}) as Dictionary
	var targets := mechanics.get("targets", {}) as Dictionary
	var relationship := str(targets.get("relationship", ""))
	var count := int(targets.get("count", 0))
	var target_id := str(intent.get("target_id", ""))
	var skill_id := str(activation.get("skill_id", ""))
	if count <= 0:
		if not target_id.is_empty():
			errors.append("Skill %s does not accept an explicit target" % skill_id)
		return errors
	if target_id.is_empty():
		errors.append("Skill %s requires exactly one %s target" % [skill_id, relationship])
		return errors
	var target := _find_fighter(state, target_id)
	if target.is_empty() or not _is_active_fighter(target):
		errors.append("Skill %s references an unavailable target: %s" % [skill_id, target_id])
		return errors
	var actor_id := str(actor.get("id", ""))
	match relationship:
		"enemy":
			if str(target.get("team", "")) == str(actor.get("team", "")):
				errors.append("Skill %s requires an enemy target" % skill_id)
		"ally":
			if target_id == actor_id or str(target.get("team", "")) != str(actor.get("team", "")):
				errors.append("Skill %s requires another active ally target" % skill_id)
		"self":
			if target_id != actor_id:
				errors.append("Skill %s requires self target" % skill_id)
		_:
			errors.append(
				"Skill %s has unsupported target relationship: %s" % [skill_id, relationship]
			)
	return errors


func _is_active_fighter(fighter: Dictionary) -> bool:
	var pv := float((fighter.get("stats", {}) as Dictionary).get("PV", 0.0))
	if fighter.has("current_pv"):
		pv = float(fighter.get("current_pv", pv))
	return pv > 0.0


func _fighter_exists(state: Dictionary, fighter_id: String) -> bool:
	return not _find_fighter(state, fighter_id).is_empty()


func _find_fighter(state: Dictionary, fighter_id: String) -> Dictionary:
	var fighters_value: Variant = state.get("fighters", [])
	if not fighters_value is Array:
		return {}
	for raw_fighter in fighters_value as Array:
		if (
			raw_fighter is Dictionary
			and str((raw_fighter as Dictionary).get("id", "")) == fighter_id
		):
			return raw_fighter as Dictionary
	return {}
