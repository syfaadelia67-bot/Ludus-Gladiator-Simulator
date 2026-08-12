extends RefCounted

const CombatActionCatalogScript = preload("res://scripts/combat/combat_action_catalog.gd")
const DEMO_RUNTIME_RANK := 1

var _action_catalog = CombatActionCatalogScript.new()


func resolve_desired_action(
	fighter: Dictionary, desired_action: Dictionary, skill_mechanics_by_id: Dictionary
) -> Dictionary:
	var skill_id := str(desired_action.get("skill_id", ""))
	if skill_id.is_empty():
		return {
			"status": "ready",
			"errors": [],
			"desired_action": desired_action.duplicate(true),
			"skill_activation": {},
		}
	if not skill_mechanics_by_id.has(skill_id):
		return _rejected("unknown_skill", ["Unknown Combat V1 skill: %s" % skill_id])
	if (
		str(fighter.get("entity_type", "")).to_lower() == "beast"
		or not str(fighter.get("beast_id", "")).is_empty()
	):
		return _rejected("beast_skill_forbidden", ["Beasts cannot activate Combat V1 skills"])

	var entry := skill_mechanics_by_id.get(skill_id, {}) as Dictionary
	if str(entry.get("status", "")) != "frozen":
		return _rejected("skill_not_frozen", ["Skill %s is not frozen" % skill_id])
	var mechanics := entry.get("mechanics", {}) as Dictionary
	var mapping := mechanics.get("action_mapping", {}) as Dictionary
	var mapped_action_id := str(mapping.get("base_action", ""))
	if not _action_catalog.is_action_id_valid(mapped_action_id):
		return _rejected(
			"invalid_skill_action_mapping",
			["Skill %s maps to unsupported action %s" % [skill_id, mapped_action_id]],
		)

	var equipment_errors := _validate_equipment_requirements(fighter, mechanics)
	if not equipment_errors.is_empty():
		return _rejected("skill_equipment_requirement_failed", equipment_errors)

	var activation := {
		"skill_id": skill_id,
		"rank": DEMO_RUNTIME_RANK,
		"mapped_action_id": mapped_action_id,
		"mechanics": mechanics.duplicate(true),
		"progression": (entry.get("progression", {}) as Dictionary).duplicate(true),
	}
	var resolved := desired_action.duplicate(true)
	resolved["action_id"] = mapped_action_id
	resolved["skill_activation"] = activation.duplicate(true)
	resolved.erase("skill_id")
	return {
		"status": "ready",
		"errors": [],
		"desired_action": resolved,
		"skill_activation": activation.duplicate(true),
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"authority": "skill_intent_translation_only",
		"runtime_rank": DEMO_RUNTIME_RANK,
		"higher_rank_runtime_enabled": false,
		"activation_embedded_in_translated_intent": true,
		"equipment_requirements_enforced": true,
		"specialized_category_is_activation_gate": false,
		"damage_authority": "combat_simulator",
		"ko_authority": "combat_simulator",
		"winner_authority": "combat_simulator",
		"beast_skills_allowed": false,
		"save_version_change_required": false,
	}


func _validate_equipment_requirements(fighter: Dictionary, mechanics: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var context := fighter.get("equipment_context", {}) as Dictionary
	for raw_requirement in mechanics.get("equipment_requirements", []) as Array:
		var requirement := str(raw_requirement)
		var met := false
		match requirement:
			"weapon":
				met = bool(context.get("has_weapon", false))
			"shield":
				met = bool(context.get("has_shield", false))
			_:
				met = (context.get("tags", []) as Array).has(requirement)
		if not met:
			errors.append(
				(
					"Fighter %s does not meet skill equipment requirement: %s"
					% [str(fighter.get("id", "")), requirement]
				)
			)
	return errors


func _rejected(reason: String, errors: Array) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"desired_action": {},
		"skill_activation": {},
	}
