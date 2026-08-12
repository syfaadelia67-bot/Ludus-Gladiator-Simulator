extends RefCounted

const CombatActionCatalogScript = preload("res://scripts/combat/combat_action_catalog.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")
const GT1CombatIntentBridgeScript = preload("res://scripts/combat/gt1_combat_intent_bridge.gd")
const GT1CombatPresentationSnapshotScript = preload(
	"res://scripts/combat/gt1_combat_presentation_snapshot.gd"
)
const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")
const GT1Month13HostScript = preload("res://scripts/combat/gt1_month_13_host.gd")
const GT1Month16HostScript = preload("res://scripts/combat/gt1_month_16_host.gd")
const GT1Month20HostScript = preload("res://scripts/combat/gt1_month_20_host.gd")

const DEMO_SKILL_RANK := 1

var _action_catalog = CombatActionCatalogScript.new()
var _policy_contract = CombatPolicyContractScript.new()
var _intent_bridge = GT1CombatIntentBridgeScript.new()
var _presentation = GT1CombatPresentationSnapshotScript.new()
var _runtime = GT1CombatRuntimeScript.new()
var _month_13_host = GT1Month13HostScript.new()
var _month_16_host = GT1Month16HostScript.new()
var _month_20_host = GT1Month20HostScript.new()


func start_gt1_session(
	month: int, player_team_id: String, player_ids_by_bout: Array, opponent_fighters_by_bout: Array
) -> Dictionary:
	return (
		_runtime
		. start_encounter_from_live_roster(
			month,
			player_team_id,
			player_ids_by_bout,
			opponent_fighters_by_bout,
		)
	)


func start_month_13_session(
	player_gladiator_id: String, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	return _month_13_host.start(player_gladiator_id, player_team_id, opponent_fighters)


func prepare_month_13_request(
	player_gladiator_id: String, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	return _month_13_host.prepare_request(player_gladiator_id, player_team_id, opponent_fighters)


func start_month_16_human_session(
	player_gladiator_ids: Array, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	return _month_16_host.start_human(player_gladiator_ids, player_team_id, opponent_fighters)


func prepare_month_16_human_request(
	player_gladiator_ids: Array, player_team_id: String, opponent_fighters: Array
) -> Dictionary:
	return _month_16_host.prepare_human_request(
		player_gladiator_ids, player_team_id, opponent_fighters
	)


func start_month_16_beast_session(
	player_gladiator_ids: Array, player_team_id: String, beast_ids: Array, opponent_team_id: String
) -> Dictionary:
	return _month_16_host.start_beasts(
		player_gladiator_ids, player_team_id, beast_ids, opponent_team_id
	)


func prepare_month_16_beast_request(
	player_gladiator_ids: Array, player_team_id: String, beast_ids: Array, opponent_team_id: String
) -> Dictionary:
	return _month_16_host.prepare_beast_request(
		player_gladiator_ids, player_team_id, beast_ids, opponent_team_id
	)


func get_month_16_beast_readiness() -> Dictionary:
	return _month_16_host.get_beast_readiness()


func start_month_20_session(
	player_ids_by_bout: Array, player_team_id: String, opponent_fighters_by_bout: Array
) -> Dictionary:
	return _month_20_host.start(player_ids_by_bout, player_team_id, opponent_fighters_by_bout)


func prepare_month_20_request(
	player_ids_by_bout: Array, player_team_id: String, opponent_fighters_by_bout: Array
) -> Dictionary:
	return _month_20_host.prepare_request(
		player_ids_by_bout, player_team_id, opponent_fighters_by_bout
	)


func advance_exchange(
	session: Dictionary, player_intents_by_actor: Dictionary, ai_requests_by_actor: Dictionary
) -> Dictionary:
	return (
		_intent_bridge
		. advance_exchange(
			session,
			player_intents_by_actor,
			ai_requests_by_actor,
		)
	)


func build_player_intents(
	session: Dictionary, option_id: String, targets_by_actor: Dictionary = {}
) -> Dictionary:
	var state := _active_state(session)
	if state.is_empty():
		return _rejected(
			"missing_active_combat_state", ["Combat V1 Arena requires an active GT I state"]
		)
	var option := get_player_option_contract(session, option_id)
	if option.is_empty():
		return _rejected("invalid_action", ["Unsupported Combat V1 option: %s" % option_id])
	if not bool(option.get("available", true)):
		return _rejected(
			"option_unavailable",
			[str(option.get("unavailable_reason", "La opción no está disponible."))],
		)

	var player_team_id := str(session.get("player_team_id", ""))
	if player_team_id.is_empty():
		return _rejected("missing_player_team", ["Combat V1 Arena requires player_team_id"])

	DataRepository.load_all()
	_policy_contract.set_skill_mechanics(DataRepository.get_skill_mechanics_v1())
	var intents: Dictionary = {}
	for raw_fighter in state.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("team", "")) != player_team_id or not _is_active(fighter):
			continue
		var actor_id := str(fighter.get("id", ""))
		var desired_action := {"actor_id": actor_id}
		if str(option.get("option_type", "action")) == "skill":
			desired_action["skill_id"] = option_id
		else:
			desired_action["action_id"] = option_id
		var target_id := str(targets_by_actor.get(actor_id, ""))
		if target_id.is_empty() and str(option.get("target_relationship", "")) == "ally":
			target_id = _single_active_ally_id(state, player_team_id, actor_id)
		if bool(option.get("target_required", false)):
			desired_action["target_id"] = target_id
		var errors := _policy_contract.validate_desired_action(state, desired_action)
		if not errors.is_empty():
			return _rejected("invalid_player_intent", errors)
		intents[actor_id] = desired_action

	if intents.is_empty():
		return _rejected(
			"no_active_player_fighters", ["Combat V1 Arena found no active player fighters"]
		)
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"player_intents_by_actor": intents.duplicate(true),
	}


func build_snapshot(session: Dictionary) -> Dictionary:
	return _presentation.build(session, TournamentManager.get_gt1_summary())


func get_action_contracts() -> Array[Dictionary]:
	return _action_catalog.get_action_contracts()


func get_player_option_contracts(session: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_contract in _action_catalog.get_action_contracts():
		var contract := (raw_contract as Dictionary).duplicate(true)
		contract["option_type"] = "action"
		contract["name"] = str(contract.get("id", ""))
		contract["available"] = true
		contract["unavailable_reason"] = ""
		contract["manual_target_required"] = bool(contract.get("target_required", false))
		result.append(contract)
	DataRepository.load_all()
	var names_by_id: Dictionary = {}
	var categories_by_id: Dictionary = {}
	for raw_skill in DataRepository.get_skills():
		var skill := raw_skill as Dictionary
		var skill_id := str(skill.get("id", ""))
		names_by_id[skill_id] = str(skill.get("name", skill_id))
		categories_by_id[skill_id] = str(skill.get("category", "general"))
	for raw_entry in DataRepository.get_skill_mechanics_v1():
		var entry := raw_entry as Dictionary
		var skill_id := str(entry.get("id", ""))
		var mechanics := entry.get("mechanics", {}) as Dictionary
		var targets := mechanics.get("targets", {}) as Dictionary
		var cost := mechanics.get("cost", {}) as Dictionary
		var contract := {
			"id": skill_id,
			"name": str(names_by_id.get(skill_id, skill_id)),
			"category": str(categories_by_id.get(skill_id, "general")),
			"option_type": "skill",
			"runtime_rank": DEMO_SKILL_RANK,
			"stamina_cost": int(cost.get("stamina", 0)),
			"target_required": int(targets.get("count", 0)) > 0,
			"target_relationship": str(targets.get("relationship", "")),
			"manual_target_required": str(targets.get("relationship", "")) == "enemy",
			"equipment_requirements":
			(mechanics.get("equipment_requirements", []) as Array).duplicate(),
			"available": true,
			"unavailable_reason": "",
		}
		_apply_live_option_availability(session, contract)
		result.append(contract)
	return result


func get_player_option_contract(session: Dictionary, option_id: String) -> Dictionary:
	for raw_contract in get_player_option_contracts(session):
		var contract := raw_contract as Dictionary
		if str(contract.get("id", "")) == option_id:
			return contract.duplicate(true)
	return {}


func get_active_enemy_ids(session: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var state := _active_state(session)
	var player_team_id := str(session.get("player_team_id", ""))
	for raw_fighter in state.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("team", "")) == player_team_id:
			continue
		if not _is_active(fighter):
			continue
		var fighter_id := str(fighter.get("id", ""))
		if not fighter_id.is_empty():
			result.append(fighter_id)
	result.sort()
	return result


func get_active_player_ids(session: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var state := _active_state(session)
	var player_team_id := str(session.get("player_team_id", ""))
	for raw_fighter in state.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("team", "")) != player_team_id:
			continue
		if not _is_active(fighter):
			continue
		var fighter_id := str(fighter.get("id", ""))
		if not fighter_id.is_empty():
			result.append(fighter_id)
	result.sort()
	return result


func option_requires_manual_target(session: Dictionary, option_id: String) -> bool:
	return bool(get_player_option_contract(session, option_id).get("manual_target_required", false))


func action_requires_target(action_id: String) -> bool:
	return bool(_action_catalog.get_action_contract(action_id).get("target_required", false))


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"session_authority": "gt1_combat_runtime",
		"intent_authority": "gt1_combat_intent_bridge",
		"presentation_authority": "gt1_combat_presentation_snapshot",
		"player_facing_setup_authority": "gt1_series_setup_runtime",
		"player_option_source": "base_actions_plus_canonical_rank_1_skills",
		"skill_runtime_rank": DEMO_SKILL_RANK,
		"higher_skill_ranks_exposed": false,
		"ally_skill_targeting": "automatic_single_active_ally",
		"month_13_host": "gt1_month_13_host",
		"month_16_host": "gt1_month_16_host",
		"month_20_host": "gt1_month_20_host",
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"low_level_explicit_snapshot_bridge_retained": true,
		"ai_request_authority": "external_limboai_policy_requests",
		"default_player_action_allowed": false,
		"default_target_allowed": false,
		"legacy_combat_manager_allowed": false,
		"save_version_change_required": false,
	}


func _apply_live_option_availability(session: Dictionary, contract: Dictionary) -> void:
	if session.is_empty() or str(session.get("status", "")) != "combat_running":
		return
	var state := _active_state(session)
	var player_team_id := str(session.get("player_team_id", ""))
	var active_players: Array[Dictionary] = []
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("team", "")) == player_team_id and _is_active(fighter):
			active_players.append(fighter)
	if str(contract.get("target_relationship", "")) == "ally" and active_players.size() < 2:
		contract["available"] = false
		contract["unavailable_reason"] = "Esta skill requiere otro gladiador aliado activo."
		return
	for fighter in active_players:
		var context := fighter.get("equipment_context", {}) as Dictionary
		for raw_requirement in contract.get("equipment_requirements", []) as Array:
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
				contract["available"] = false
				contract["unavailable_reason"] = (
					"Todos los gladiadores activos deben cumplir el requisito: %s." % requirement
				)
				return


func _single_active_ally_id(state: Dictionary, team_id: String, actor_id: String) -> String:
	var allies: Array[String] = []
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		var fighter_id := str(fighter.get("id", ""))
		if fighter_id == actor_id or str(fighter.get("team", "")) != team_id:
			continue
		if _is_active(fighter):
			allies.append(fighter_id)
	allies.sort()
	return allies[0] if allies.size() == 1 else ""


func _is_active(fighter: Dictionary) -> bool:
	return int(fighter.get("current_pv", (fighter.get("stats", {}) as Dictionary).get("PV", 0))) > 0


func _active_state(session: Dictionary) -> Dictionary:
	var active_loop_value: Variant = session.get("active_loop", null)
	if not active_loop_value is Dictionary:
		return {}
	var state_value: Variant = (active_loop_value as Dictionary).get("state", null)
	if not state_value is Dictionary:
		return {}
	return (state_value as Dictionary).duplicate(true)


func _rejected(reason: String, errors: Array) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"player_intents_by_actor": {},
	}
