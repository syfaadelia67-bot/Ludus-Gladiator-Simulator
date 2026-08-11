extends RefCounted

const CombatActionCatalogScript = preload("res://scripts/combat/combat_action_catalog.gd")

const BEAST_ALLOWED_ACTION_IDS: Array[String] = ["light", "heavy", "dodge", "reposition"]
const BEAST_FORBIDDEN_ACTION_IDS: Array[String] = ["block", "parry"]

var _action_catalog = CombatActionCatalogScript.new()


func get_allowed_action_ids(fighter: Dictionary) -> Array[String]:
	if not is_beast(fighter):
		return _action_catalog.get_action_ids()
	return BEAST_ALLOWED_ACTION_IDS.duplicate()


func get_allowed_action_contracts(fighter: Dictionary) -> Array[Dictionary]:
	var contracts: Array[Dictionary] = []
	for action_id in get_allowed_action_ids(fighter):
		contracts.append(_action_catalog.get_action_contract(action_id))
	return contracts


func is_action_allowed(fighter: Dictionary, action_id: String) -> bool:
	return get_allowed_action_ids(fighter).has(action_id)


func is_beast(fighter: Dictionary) -> bool:
	if str(fighter.get("entity_type", "")).to_lower() == "beast":
		return true
	return not str(fighter.get("beast_id", "")).is_empty()


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"default_action_source": "combat_action_catalog",
		"beast_allowed_action_ids": BEAST_ALLOWED_ACTION_IDS.duplicate(),
		"beast_forbidden_action_ids": BEAST_FORBIDDEN_ACTION_IDS.duplicate(),
		"beast_block_allowed": false,
		"beast_parry_allowed": false,
		"beast_skills_allowed": false,
		"result_authority": "combat_simulator",
		"save_version_change_required": false,
	}
