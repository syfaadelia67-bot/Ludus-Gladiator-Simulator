extends Node

const CombatV1ArenaRuntimeScript = preload("res://scripts/ui/combat_v1_arena_runtime.gd")


func run() -> void:
	_test_runtime_contract()
	_test_month_13_request_bridge()
	_test_player_intent_requires_explicit_target()
	_test_defensive_action_needs_no_target()
	print("Combat V1 Arena runtime bridge: OK")


func _test_runtime_contract() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var contract: Dictionary = runtime.get_contract()
	assert(contract.get("session_authority") == "gt1_combat_runtime")
	assert(contract.get("intent_authority") == "gt1_combat_intent_bridge")
	assert(contract.get("presentation_authority") == "gt1_combat_presentation_snapshot")
	assert(contract.get("month_13_host") == "gt1_month_13_host")
	assert(contract.get("combat_authority") == "combat_simulator")
	assert(contract.get("scoring_authority") == "tournament_manager")
	assert(contract.get("default_player_action_allowed") == false)
	assert(contract.get("default_target_allowed") == false)
	assert(contract.get("legacy_combat_manager_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _test_month_13_request_bridge() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var request: Dictionary = runtime.prepare_month_13_request(
		"player",
		"alpha",
		[
			_fighter("rival_1", "beta"),
			_fighter("rival_2", "beta"),
			_fighter("rival_3", "beta"),
		],
	)
	assert(request.get("status") == "ready")
	assert(request.get("player_ids_by_bout") == [["player"], ["player"], ["player"]])
	assert(request.get("carryover") == ["current_pv", "stamina"])
	assert(request.get("beasts_allowed") == false)
	assert(int(request.get("max_points", 0)) == 9)


func _test_player_intent_requires_explicit_target() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var session := _session()
	var rejected: Dictionary = runtime.build_player_intents(session, "light")
	assert(rejected.get("status") == "rejected")
	assert(rejected.get("reason") == "invalid_player_intent")

	var ready: Dictionary = (
		runtime
		. build_player_intents(
			session,
			"light",
			{"player": "rival"},
		)
	)
	assert(ready.get("status") == "ready")
	var intents := ready.get("player_intents_by_actor", {}) as Dictionary
	assert(intents.has("player"))
	assert((intents.get("player", {}) as Dictionary).get("action_id") == "light")
	assert((intents.get("player", {}) as Dictionary).get("target_id") == "rival")


func _test_defensive_action_needs_no_target() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var ready: Dictionary = runtime.build_player_intents(_session(), "block")
	assert(ready.get("status") == "ready")
	var desired := (
		(ready.get("player_intents_by_actor", {}) as Dictionary).get("player", {}) as Dictionary
	)
	assert(desired.get("action_id") == "block")
	assert(str(desired.get("target_id", "")).is_empty())
	assert(runtime.get_active_enemy_ids(_session()) == ["rival"])
	assert(runtime.get_active_player_ids(_session()) == ["player"])
	assert(runtime.action_requires_target("heavy"))
	assert(not runtime.action_requires_target("dodge"))


func _session() -> Dictionary:
	return {
		"status": "combat_running",
		"month": 13,
		"player_team_id": "alpha",
		"active_loop":
		{
			"state":
			{
				"format": "1v1",
				"fighters":
				[
					_fighter("player", "alpha"),
					_fighter("rival", "beta"),
				],
			},
		},
	}


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"current_pv": 100,
		"stamina": 100.0,
		"equipment": {"power": 0, "defense": 0},
	}
