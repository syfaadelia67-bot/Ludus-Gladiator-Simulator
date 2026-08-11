extends Node

const CombatBeastFighterAdapterScript = preload(
	"res://scripts/combat/combat_beast_fighter_adapter.gd"
)
const CombatFighterActionPolicyScript = preload(
	"res://scripts/combat/combat_fighter_action_policy.gd"
)
const CombatPolicyContextBuilderScript = preload(
	"res://scripts/combat/combat_policy_context_builder.gd"
)
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")

const BEAST_ACTIONS: Array[String] = ["light", "heavy", "dodge", "reposition"]
const HUMAN_ACTIONS: Array[String] = ["light", "heavy", "block", "parry", "dodge", "reposition"]


func _ready() -> void:
	DataRepository.load_all()
	var adapter = CombatBeastFighterAdapterScript.new()
	var action_policy = CombatFighterActionPolicyScript.new()
	var policy_contract = CombatPolicyContractScript.new()
	var context_builder = CombatPolicyContextBuilderScript.new()
	var beast := (
		adapter.build_from_beast_id("lion", "lion_1", "beasts").get("fighter", {}) as Dictionary
	)
	var human := _human("gladiator_1", "player")
	var state := {"format": "1v1", "fighters": [human, beast]}

	assert(action_policy.get_allowed_action_ids(human) == HUMAN_ACTIONS)
	assert(action_policy.get_allowed_action_ids(beast) == BEAST_ACTIONS)
	assert(action_policy.is_action_allowed(beast, "block") == false)
	assert(action_policy.is_action_allowed(beast, "parry") == false)
	assert(action_policy.is_action_allowed(beast, "light") == true)
	assert(action_policy.is_action_allowed(beast, "dodge") == true)

	var block_errors: Array[String] = policy_contract.validate_desired_action(
		state, {"actor_id": "lion_1", "action_id": "block"}
	)
	assert(_contains_error(block_errors, "not allowed for actor lion_1"))
	var parry_errors: Array[String] = policy_contract.validate_desired_action(
		state, {"actor_id": "lion_1", "action_id": "parry"}
	)
	assert(_contains_error(parry_errors, "not allowed for actor lion_1"))
	assert(
		(
			policy_contract
			. validate_desired_action(
				state, {"actor_id": "lion_1", "action_id": "light", "target_id": "gladiator_1"}
			)
			. is_empty()
		)
	)
	assert(
		(
			policy_contract
			. validate_desired_action(state, {"actor_id": "lion_1", "action_id": "dodge"})
			. is_empty()
		)
	)

	var context_result: Dictionary = context_builder.build_context(state, "lion_1")
	assert(context_result.get("status") == "ready")
	var context := context_result.get("context", {}) as Dictionary
	assert(context.get("available_action_ids") == BEAST_ACTIONS)
	var legal_targets := context.get("legal_targets", {}) as Dictionary
	assert(legal_targets.has("block") == false)
	assert(legal_targets.has("parry") == false)
	assert(legal_targets.get("light") == ["gladiator_1"])
	assert((context.get("action_contracts", []) as Array).size() == 4)

	var contract: Dictionary = action_policy.get_contract()
	assert(contract.get("beast_block_allowed") == false)
	assert(contract.get("beast_parry_allowed") == false)
	assert(contract.get("beast_skills_allowed") == false)
	assert(contract.get("result_authority") == "combat_simulator")
	assert(contract.get("save_version_change_required") == false)

	print("Beast Combat V1 action capability policy: OK")
	get_tree().quit(0)


func _human(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 7, "AGI": 7, "TEC": 7, "RES": 7, "PV": 60},
		"stamina": 10,
		"equipment": {"power": 0, "defense": 0},
	}


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error_message in errors:
		if error_message.contains(fragment):
			return true
	return false
