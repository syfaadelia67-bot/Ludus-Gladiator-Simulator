extends Node

const GT1CombatIntentBridgeScript = preload("res://scripts/combat/gt1_combat_intent_bridge.gd")
const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")


func run() -> void:
	_test_player_and_rival_limboai_intents_advance_gt1_exchange()
	_test_missing_player_limboai_request_stops_before_runtime()
	print("GT I LimboAI-vs-LimboAI combat intent bridge: OK")


func _test_player_and_rival_limboai_intents_advance_gt1_exchange() -> void:
	TournamentManager.import_state({})
	var fixture := _runtime_fixture()
	var runtime = GT1CombatRuntimeScript.new()
	var session := (
		runtime
		. start_encounter(
			13,
			"alpha",
			[
				_state("player", "rival_1"),
				_state("player", "rival_2"),
				_state("player", "rival_3"),
			],
		)
	)
	assert(session.get("status") == "combat_running")
	var state_before := (
		((session.get("active_loop", {}) as Dictionary).get("state", {}) as Dictionary)
		. duplicate(true)
	)

	var bridge = GT1CombatIntentBridgeScript.new()
	var next: Dictionary = (
		bridge
		. advance_exchange(
			session,
			{},
			{
				"player": _ai_request("player", "rival_1", fixture),
				"rival_1": _ai_request("rival_1", "player", fixture),
			},
		)
	)
	assert(next.get("status") == "combat_running")
	assert(next.get("last_intent_actor_ids") == ["player", "rival_1"])
	assert(
		(
			next.get("last_intent_providers")
			== {
				"player": "limboai",
				"rival_1": "limboai",
			}
		)
	)
	assert(next.get("intent_collection_authority") == "combat_intent_source_collector")
	assert(next.get("combat_authority") == "combat_simulator")
	var next_loop := next.get("active_loop", {}) as Dictionary
	assert(int(next_loop.get("exchange_index", 0)) == 1)
	assert(
		(
			((session.get("active_loop", {}) as Dictionary).get("state", {}) as Dictionary)
			== state_before
		)
	)

	var contract: Dictionary = bridge.get_contract()
	assert(contract.get("player_intents") == "limboai_policy_runner")
	assert(contract.get("rival_intents") == "limboai_policy_runner")
	assert(contract.get("legacy_player_intents") == "explicit_desired_actions")
	assert(contract.get("legacy_player_intents_runtime_required") == false)
	assert(contract.get("combat_authority") == "combat_simulator")
	assert(contract.get("bridge_may_resolve_combat") == false)
	fixture.owner.free()
	TournamentManager.import_state({})


func _test_missing_player_limboai_request_stops_before_runtime() -> void:
	TournamentManager.import_state({})
	var fixture := _runtime_fixture()
	var runtime = GT1CombatRuntimeScript.new()
	var session := (
		runtime
		. start_encounter(
			13,
			"alpha",
			[
				_state("player", "rival_1"),
				_state("player", "rival_2"),
				_state("player", "rival_3"),
			],
		)
	)
	assert(session.get("status") == "combat_running")
	var bridge = GT1CombatIntentBridgeScript.new()
	var result: Dictionary = (
		bridge
		. advance_exchange(
			session,
			{},
			{
				"rival_1": _ai_request("rival_1", "player", fixture),
			},
		)
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "gt1_intent_collection_failed")
	assert(_contains_error(result, "Missing intent source for active fighter player"))
	assert(TournamentManager.get_gt1_summary().get("player_bouts") == 0)
	fixture.owner.free()
	TournamentManager.import_state({})


func _ai_request(actor_id: String, target_id: String, fixture: Dictionary) -> Dictionary:
	return {
		"policy_proposal":
		{
			"actor_id": actor_id,
			"action_id": "light",
			"target_id": target_id,
		},
		"agent": fixture.agent,
		"instance_owner": fixture.owner,
	}


func _state(player_id: String, rival_id: String) -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter(player_id, "alpha"),
			_fighter(rival_id, "beta"),
		],
	}


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"stamina": 100,
		"equipment": {"power": 0, "defense": 0},
	}


func _runtime_fixture() -> Dictionary:
	var owner := Node.new()
	var agent := Node.new()
	owner.add_child(agent)
	return {"owner": owner, "agent": agent}


func _contains_error(result: Dictionary, fragment: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
