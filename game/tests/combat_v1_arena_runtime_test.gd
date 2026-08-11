extends Node

const CombatV1ArenaRuntimeScript = preload("res://scripts/ui/combat_v1_arena_runtime.gd")


func run() -> void:
	DataRepository.load_all()
	_test_runtime_contract()
	_test_player_facing_catalog()
	_test_month_13_catalog_request_bridge()
	_test_month_16_catalog_request_bridge()
	_test_month_20_catalog_request_bridge()
	_test_missing_catalog_selection_fails_closed()
	_test_month_13_request_bridge()
	_test_month_16_request_bridge()
	_test_month_16_beast_request_bridge()
	_test_month_20_request_bridge()
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
	assert(contract.get("month_16_host") == "gt1_month_16_host")
	assert(contract.get("month_20_host") == "gt1_month_20_host")
	assert(contract.get("combat_authority") == "combat_simulator")
	assert(contract.get("scoring_authority") == "tournament_manager")
	assert(contract.get("human_opponent_selection_authority") == "gt1_rival_combat_snapshot_provider")
	assert(contract.get("player_facing_rival_catalog") == "DataRepository.rival_combat_v1_snapshots")
	assert(contract.get("player_facing_rival_ludi") == "DataRepository.rival_ludi")
	assert(contract.get("canonical_rival_team_id") == "rival_team")
	assert(contract.get("low_level_explicit_snapshot_bridge_retained") == true)
	assert(contract.get("month_16_beast_selection_authority") == "combat_beast_fighter_adapter")
	assert(contract.get("player_facing_beast_catalog") == "DataRepository.beasts")
	assert(contract.get("explicit_series_selection_required") == true)
	assert(contract.get("generated_opponents_allowed") == false)
	assert(contract.get("default_player_action_allowed") == false)
	assert(contract.get("default_target_allowed") == false)
	assert(contract.get("legacy_combat_manager_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _test_player_facing_catalog() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var month_13 := runtime.get_gt1_setup_catalog(13)
	assert(month_13.get("status") == "ready")
	assert(int(month_13.get("player_slots", 0)) == 1)
	assert(int(month_13.get("opponent_slots", 0)) == 3)
	assert(month_13.get("opponent_modes") == ["human"])
	assert((month_13.get("rivals", []) as Array).size() == 7)
	assert((month_13.get("beasts", []) as Array).is_empty())
	for raw_rival in month_13.get("rivals", []) as Array:
		assert(raw_rival is Dictionary)
		assert(((raw_rival as Dictionary).get("fighters", []) as Array).size() == 3)

	var month_16 := runtime.get_gt1_setup_catalog(16)
	assert(month_16.get("status") == "ready")
	assert(int(month_16.get("player_slots", 0)) == 3)
	assert(int(month_16.get("opponent_slots", 0)) == 3)
	assert(month_16.get("opponent_modes") == ["human", "beast"])
	assert((month_16.get("beasts", []) as Array).size() == 3)

	var month_20 := runtime.get_gt1_setup_catalog(20)
	assert(month_20.get("status") == "ready")
	assert(int(month_20.get("player_slots", 0)) == 6)
	assert(int(month_20.get("opponent_slots", 0)) == 6)
	assert(month_20.get("opponent_modes") == ["human"])
	assert(month_20.get("explicit_selection_required") == true)
	assert(month_20.get("generated_opponents_allowed") == false)


func _test_month_13_catalog_request_bridge() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var request := runtime.prepare_month_13_catalog_request(
		"player",
		"alpha",
		"cassianus",
		["rival_heavy", "rival_agile", "rival_technical"],
	)
	assert(request.get("status") == "ready")
	assert(request.get("player_ids_by_bout") == [["player"], ["player"], ["player"]])
	var bouts := request.get("opponent_fighters_by_bout", []) as Array
	assert(bouts.size() == 3)
	assert(str(((bouts[0] as Array)[0] as Dictionary).get("id", "")) == "rival_heavy")
	assert(str(((bouts[1] as Array)[0] as Dictionary).get("id", "")) == "rival_agile")
	assert(str(((bouts[2] as Array)[0] as Dictionary).get("id", "")) == "rival_technical")


func _test_month_16_catalog_request_bridge() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var request := runtime.prepare_month_16_catalog_human_request(
		["p1", "p2", "p3"],
		"alpha",
		"flavianus",
		["rival_technical", "rival_heavy", "rival_agile"],
	)
	assert(request.get("status") == "ready")
	assert(request.get("player_ids_by_bout") == [["p1"], ["p2"], ["p3"]])
	assert(request.get("independent_bouts") == true)
	assert(request.get("carryover") == [])


func _test_month_20_catalog_request_bridge() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var request := runtime.prepare_month_20_catalog_request(
		[["p1", "p2"], ["p1", "p3"], ["p1", "p3"]],
		"alpha",
		"drusus",
		[
			["rival_heavy", "rival_agile"],
			["rival_heavy", "rival_technical"],
			["rival_agile", "rival_technical"],
		],
	)
	assert(request.get("status") == "ready")
	assert(request.get("format") == "2v2")
	assert(request.get("substitution_used") == true)
	var bouts := request.get("opponent_fighters_by_bout", []) as Array
	assert(bouts.size() == 3)
	assert((bouts[0] as Array).size() == 2)
	assert((bouts[1] as Array).size() == 2)
	assert((bouts[2] as Array).size() == 2)


func _test_missing_catalog_selection_fails_closed() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var missing := runtime.prepare_month_13_catalog_request(
		"player", "alpha", "cassianus", ["rival_heavy", "", "rival_technical"]
	)
	assert(missing.get("status") == "rejected")
	assert(missing.get("generated_opponents_allowed") == false)
	var unknown := runtime.prepare_month_16_catalog_human_request(
		["p1", "p2", "p3"],
		"alpha",
		"unknown_ludus",
		["rival_heavy", "rival_agile", "rival_technical"],
	)
	assert(unknown.get("status") == "rejected")
	assert(unknown.get("generated_opponents_allowed") == false)
	assert(runtime.get_gt1_setup_catalog(12).get("status") == "rejected")


func _test_month_13_request_bridge() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var request: Dictionary = (
		runtime
		. prepare_month_13_request(
			"player",
			"alpha",
			[
				_fighter("rival_1", "beta"),
				_fighter("rival_2", "beta"),
				_fighter("rival_3", "beta"),
			],
		)
	)
	assert(request.get("status") == "ready")
	assert(request.get("player_ids_by_bout") == [["player"], ["player"], ["player"]])
	assert(request.get("carryover") == ["current_pv", "stamina"])
	assert(request.get("beasts_allowed") == false)
	assert(int(request.get("max_points", 0)) == 9)


func _test_month_16_request_bridge() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var request: Dictionary = (
		runtime
		. prepare_month_16_human_request(
			["player_1", "player_2", "player_3"],
			"alpha",
			[
				_fighter("rival_1", "beta"),
				_fighter("rival_2", "beta"),
				_fighter("rival_3", "beta"),
			],
		)
	)
	assert(request.get("status") == "ready")
	assert(request.get("player_ids_by_bout") == [["player_1"], ["player_2"], ["player_3"]])
	assert(request.get("carryover") == [])
	assert(request.get("independent_bouts") == true)
	assert(request.get("beasts_allowed_by_design") == true)
	assert(request.get("beast_selection_ready") == true)
	assert(int(request.get("max_points", 0)) == 9)
	var readiness: Dictionary = runtime.get_month_16_beast_readiness()
	assert(readiness.get("month") == 16)
	assert(readiness.get("beast_selection_ready") == true)
	assert(readiness.get("canonical_beast_stats_ready") == true)
	assert(readiness.get("runtime_beast_adapter_ready") == true)
	assert(readiness.get("invent_stats_allowed") == false)


func _test_month_16_beast_request_bridge() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var request: Dictionary = (
		runtime
		. prepare_month_16_beast_request(
			["player_1", "player_2", "player_3"],
			"alpha",
			["boar", "lion", "bear"],
			"beasts",
		)
	)
	assert(request.get("status") == "ready")
	var bouts := request.get("opponent_fighters_by_bout", []) as Array
	assert(bouts.size() == 3)
	for index in range(bouts.size()):
		var beast := ((bouts[index] as Array)[0]) as Dictionary
		assert(beast.get("entity_type") == "beast")
		assert(beast.get("team") == "beasts")
		assert(beast.get("can_block") == false)
		assert(beast.get("can_parry") == false)


func _test_month_20_request_bridge() -> void:
	var runtime = CombatV1ArenaRuntimeScript.new()
	var request: Dictionary = (
		runtime
		. prepare_month_20_request(
			[["p1", "p2"], ["p1", "p3"], ["p1", "p3"]],
			"alpha",
			[
				[_fighter("r1a", "beta"), _fighter("r1b", "beta")],
				[_fighter("r2a", "beta"), _fighter("r2b", "beta")],
				[_fighter("r3a", "beta"), _fighter("r3b", "beta")],
			],
		)
	)
	assert(request.get("status") == "ready")
	assert(request.get("format") == "2v2")
	assert(request.get("substitution_used") == true)
	assert(request.get("carryover") == ["current_pv", "stamina"])
	assert(int(request.get("substitution_limit", 0)) == 1)
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
