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
const GT1RivalCombatSnapshotProviderScript = preload(
	"res://scripts/combat/gt1_rival_combat_snapshot_provider.gd"
)

const GT1_MONTHS := [13, 16, 20]
const CANONICAL_RIVAL_TEAM_ID := "rival_team"
const BOUT_COUNT := 3

var _action_catalog = CombatActionCatalogScript.new()
var _policy_contract = CombatPolicyContractScript.new()
var _intent_bridge = GT1CombatIntentBridgeScript.new()
var _presentation = GT1CombatPresentationSnapshotScript.new()
var _runtime = GT1CombatRuntimeScript.new()
var _month_13_host = GT1Month13HostScript.new()
var _month_16_host = GT1Month16HostScript.new()
var _month_20_host = GT1Month20HostScript.new()
var _rival_provider = GT1RivalCombatSnapshotProviderScript.new()


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


func get_gt1_setup_catalog(month: int) -> Dictionary:
	if not GT1_MONTHS.has(month):
		return _setup_rejected(
			"unsupported_gt1_month", ["Player-facing GT I setup only supports months XIII, XVI and XX"]
		)
	var rivals: Array[Dictionary] = []
	for raw_ludus in DataRepository.get_rival_ludi():
		if not raw_ludus is Dictionary:
			return _setup_rejected(
				"invalid_rival_catalog", ["Canonical rival Ludus catalog contains an invalid entry"]
			)
		var ludus := raw_ludus as Dictionary
		var rival_id := str(ludus.get("id", ""))
		var profiles := _get_rival_profiles(rival_id)
		if profiles.get("status") != "ready":
			return profiles
		rivals.append(
			{
				"id": rival_id,
				"name": str(ludus.get("name", rival_id)),
				"fighters": (profiles.get("fighters", []) as Array).duplicate(true),
			}
		)
	var beasts: Array[Dictionary] = []
	if month == 16:
		var beast_readiness := get_month_16_beast_readiness()
		if beast_readiness.get("beast_selection_ready") != true:
			return _setup_rejected(
				"beast_catalog_not_ready",
				["Month XVI canonical beast catalog is not ready for player-facing setup"],
			)
		for raw_beast in DataRepository.beasts:
			if not raw_beast is Dictionary:
				return _setup_rejected(
					"invalid_beast_catalog", ["Canonical beast catalog contains an invalid entry"]
				)
			var beast := raw_beast as Dictionary
			beasts.append(
				{
					"id": str(beast.get("id", "")),
					"name": str(beast.get("name", "")),
					"stats":
					{
						"FUE": beast.get("FUE"),
						"AGI": beast.get("AGI"),
						"TEC": beast.get("TEC"),
						"RES": beast.get("RES"),
						"PV": beast.get("PV"),
					},
					"stamina": beast.get("stamina"),
				}
			)
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"month": month,
		"player_slots": 6 if month == 20 else (3 if month == 16 else 1),
		"opponent_slots": 6 if month == 20 else 3,
		"opponent_modes": ["human", "beast"] if month == 16 else ["human"],
		"rivals": rivals.duplicate(true),
		"beasts": beasts.duplicate(true),
		"rival_team_id": CANONICAL_RIVAL_TEAM_ID,
		"explicit_selection_required": true,
		"generated_opponents_allowed": false,
	}


func prepare_month_13_catalog_request(
	player_gladiator_id: String,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids: Array
) -> Dictionary:
	var resolved := _resolve_rival_singles(rival_ludus_id, rival_fighter_ids)
	if resolved.get("status") != "ready":
		return resolved
	return prepare_month_13_request(
		player_gladiator_id,
		player_team_id,
		resolved.get("fighters", []) as Array,
	)


func start_month_13_catalog_session(
	player_gladiator_id: String,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids: Array
) -> Dictionary:
	return _start_prepared_request(
		prepare_month_13_catalog_request(
			player_gladiator_id, player_team_id, rival_ludus_id, rival_fighter_ids
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


func prepare_month_16_catalog_human_request(
	player_gladiator_ids: Array,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids: Array
) -> Dictionary:
	var resolved := _resolve_rival_singles(rival_ludus_id, rival_fighter_ids)
	if resolved.get("status") != "ready":
		return resolved
	return prepare_month_16_human_request(
		player_gladiator_ids,
		player_team_id,
		resolved.get("fighters", []) as Array,
	)


func start_month_16_catalog_human_session(
	player_gladiator_ids: Array,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids: Array
) -> Dictionary:
	return _start_prepared_request(
		prepare_month_16_catalog_human_request(
			player_gladiator_ids, player_team_id, rival_ludus_id, rival_fighter_ids
		)
	)


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


func prepare_month_20_catalog_request(
	player_ids_by_bout: Array,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids_by_bout: Array
) -> Dictionary:
	var resolved := _resolve_rival_pairs(rival_ludus_id, rival_fighter_ids_by_bout)
	if resolved.get("status") != "ready":
		return resolved
	return prepare_month_20_request(
		player_ids_by_bout,
		player_team_id,
		resolved.get("fighters_by_bout", []) as Array,
	)


func start_month_20_catalog_session(
	player_ids_by_bout: Array,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids_by_bout: Array
) -> Dictionary:
	return _start_prepared_request(
		prepare_month_20_catalog_request(
			player_ids_by_bout,
			player_team_id,
			rival_ludus_id,
			rival_fighter_ids_by_bout,
		)
	)


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
		"month_16_host": "gt1_month_16_host",
		"month_20_host": "gt1_month_20_host",
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"human_opponent_selection_authority": "gt1_rival_combat_snapshot_provider",
		"player_facing_rival_catalog": "DataRepository.rival_combat_v1_snapshots",
		"player_facing_rival_ludi": "DataRepository.rival_ludi",
		"canonical_rival_team_id": CANONICAL_RIVAL_TEAM_ID,
		"low_level_explicit_snapshot_bridge_retained": true,
		"month_16_beast_selection_authority": "combat_beast_fighter_adapter",
		"player_facing_beast_catalog": "DataRepository.beasts",
		"explicit_series_selection_required": true,
		"generated_opponents_allowed": false,
		"ai_request_authority": "external_limboai_policy_requests",
		"default_player_action_allowed": false,
		"default_target_allowed": false,
		"legacy_combat_manager_allowed": false,
		"save_version_change_required": false,
	}


func _get_rival_profiles(rival_ludus_id: String) -> Dictionary:
	var entries := DataRepository.get_rival_combat_v1_snapshots_for_ludus(rival_ludus_id)
	if entries.is_empty():
		return _setup_rejected(
			"rival_profiles_unavailable",
			["No canonical Combat V1 profiles are available for %s" % rival_ludus_id],
		)
	var fighters: Array[Dictionary] = []
	var seen_ids: Array[String] = []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			return _setup_rejected(
				"invalid_rival_catalog", ["Canonical rival snapshot catalog contains an invalid entry"]
			)
		var fighter_value: Variant = (raw_entry as Dictionary).get("fighter", {})
		if not fighter_value is Dictionary:
			return _setup_rejected(
				"invalid_rival_catalog", ["Canonical rival snapshot entry is missing fighter data"]
			)
		var fighter_id := str((fighter_value as Dictionary).get("id", ""))
		if fighter_id.is_empty() or seen_ids.has(fighter_id):
			return _setup_rejected(
				"invalid_rival_catalog", ["Canonical rival profile ids must be non-empty and unique"]
			)
		seen_ids.append(fighter_id)
		var resolved := _rival_provider.get_snapshot(
			rival_ludus_id, fighter_id, CANONICAL_RIVAL_TEAM_ID
		)
		if resolved.get("status") != "ready":
			return _setup_rejected(
				str(resolved.get("reason", "invalid_rival_catalog")),
				resolved.get("errors", []) as Array,
			)
		var fighter := resolved.get("fighter_snapshot", {}) as Dictionary
		fighters.append(
			{
				"id": fighter_id,
				"stats": (fighter.get("stats", {}) as Dictionary).duplicate(true),
				"stamina": fighter.get("stamina"),
			}
		)
	fighters.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.id) < str(b.id))
	return {"status": "ready", "reason": "", "errors": [], "fighters": fighters}


func _resolve_rival_singles(rival_ludus_id: String, fighter_ids: Array) -> Dictionary:
	if fighter_ids.size() != BOUT_COUNT:
		return _setup_rejected(
			"invalid_rival_series_selection",
			["GT I 1v1 setup requires exactly three explicit rival fighter selections"],
		)
	var fighters: Array = []
	for index in range(fighter_ids.size()):
		var fighter_id := str(fighter_ids[index])
		var resolved := _rival_provider.get_snapshot(
			rival_ludus_id, fighter_id, CANONICAL_RIVAL_TEAM_ID
		)
		if resolved.get("status") != "ready":
			return _setup_rejected(
				str(resolved.get("reason", "rival_combat_snapshot_unavailable")),
				resolved.get("errors", []) as Array,
			)
		fighters.append((resolved.get("fighter_snapshot", {}) as Dictionary).duplicate(true))
	return {"status": "ready", "reason": "", "errors": [], "fighters": fighters}


func _resolve_rival_pairs(rival_ludus_id: String, fighter_ids_by_bout: Array) -> Dictionary:
	if fighter_ids_by_bout.size() != BOUT_COUNT:
		return _setup_rejected(
			"invalid_rival_series_selection",
			["GT I 2v2 setup requires exactly three explicit rival pair selections"],
		)
	var fighters_by_bout: Array = []
	for index in range(fighter_ids_by_bout.size()):
		var raw_pair: Variant = fighter_ids_by_bout[index]
		if not raw_pair is Array or (raw_pair as Array).size() != 2:
			return _setup_rejected(
				"invalid_rival_series_selection",
				["GT I month XX rival bout %d requires exactly two profile ids" % [index + 1]],
			)
		var pair: Array = []
		for raw_id in raw_pair as Array:
			var resolved := _rival_provider.get_snapshot(
				rival_ludus_id, str(raw_id), CANONICAL_RIVAL_TEAM_ID
			)
			if resolved.get("status") != "ready":
				return _setup_rejected(
					str(resolved.get("reason", "rival_combat_snapshot_unavailable")),
					resolved.get("errors", []) as Array,
				)
			pair.append((resolved.get("fighter_snapshot", {}) as Dictionary).duplicate(true))
		fighters_by_bout.append(pair)
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"fighters_by_bout": fighters_by_bout.duplicate(true),
	}


func _start_prepared_request(request: Dictionary) -> Dictionary:
	if request.get("status") != "ready":
		return request
	return (
		_runtime
		. start_encounter_from_live_roster(
			int(request.get("month", 0)),
			str(request.get("player_team_id", "")),
			request.get("player_ids_by_bout", []) as Array,
			request.get("opponent_fighters_by_bout", []) as Array,
		)
	)


func _active_state(session: Dictionary) -> Dictionary:
	var active_loop_value: Variant = session.get("active_loop", null)
	if not active_loop_value is Dictionary:
		return {}
	var state_value: Variant = (active_loop_value as Dictionary).get("state", null)
	if not state_value is Dictionary:
		return {}
	return (state_value as Dictionary).duplicate(true)


func _setup_rejected(reason: String, errors: Array) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"generated_opponents_allowed": false,
	}


func _rejected(reason: String, errors: Array) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"player_intents_by_actor": {},
	}
