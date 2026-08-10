extends RefCounted

const CombatActionCatalogScript = preload("res://scripts/combat/combat_action_catalog.gd")
const CombatPolicyContractScript = preload("res://scripts/combat/combat_policy_contract.gd")
const GT1CombatIntentBridgeScript = preload("res://scripts/combat/gt1_combat_intent_bridge.gd")
const GT1CombatPresentationSnapshotScript = preload(
	"res://scripts/combat/gt1_combat_presentation_snapshot.gd"
)
const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")
const GT1Month13HostScript = preload("res://scripts/combat/gt1_month_13_host.gd")

var _action_catalog = CombatActionCatalogScript.new()
var _policy_contract = CombatPolicyContractScript.new()
var _intent_bridge = GT1CombatIntentBridgeScript.new()
var _presentation = GT1CombatPresentationSnapshotScript.new()
var _runtime = GT1CombatRuntimeScript.new()
var _month_13_host = GT1Month13HostScript.new()


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
	session: Dictionary, action_id: String, targets_by_actor: Dictionary = {}
) -> Dictionary:
	var state := _active_state(session)
	if state.is_empty():
		return _rejected(
			"missing_active_combat_state", ["Combat V1 Arena requires an active GT I state"]
		)
	if not _action_catalog.is_action_id_valid(action_id):
		return _rejected("invalid_action", ["Unsupported Combat V1 action: %s" % action_id])

	var player_team_id := str(session.get("player_team_id", ""))
	if player_team_id.is_empty():
		return _rejected("missing_player_team", ["Combat V1 Arena requires player_team_id"])

	var intents: Dictionary = {}
	for raw_fighter in state.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("team", "")) != player_team_id:
			continue
		if (
			int(fighter.get("current_pv", (fighter.get("stats", {}) as Dictionary).get("PV", 0)))
			<= 0
		):
			continue
		var actor_id := str(fighter.get("id", ""))
		var desired_action := {
			"actor_id": actor_id,
			"action_id": action_id,
			"target_id": str(targets_by_actor.get(actor_id, "")),
		}
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
		if (
			int(fighter.get("current_pv", (fighter.get("stats", {}) as Dictionary).get("PV", 0)))
			<= 0
		):
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
		if (
			int(fighter.get("current_pv", (fighter.get("stats", {}) as Dictionary).get("PV", 0)))
			<= 0
		):
			continue
		var fighter_id := str(fighter.get("id", ""))
		if not fighter_id.is_empty():
			result.append(fighter_id)
	result.sort()
	return result


func action_requires_target(action_id: String) -> bool:
	return bool(_action_catalog.get_action_contract(action_id).get("target_required", false))


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"session_authority": "gt1_combat_runtime",
		"intent_authority": "gt1_combat_intent_bridge",
		"presentation_authority": "gt1_combat_presentation_snapshot",
		"month_13_host": "gt1_month_13_host",
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"opponent_selection_authority": "external_explicit_snapshots",
		"ai_request_authority": "external_limboai_policy_requests",
		"default_player_action_allowed": false,
		"default_target_allowed": false,
		"legacy_combat_manager_allowed": false,
		"save_version_change_required": false,
	}


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
