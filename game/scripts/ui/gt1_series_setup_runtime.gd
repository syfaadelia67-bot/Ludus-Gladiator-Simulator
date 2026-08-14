extends RefCounted

const CombatV1ArenaRuntimeScript = preload("res://scripts/ui/combat_v1_arena_runtime.gd")
const GT1RivalCombatSnapshotProviderScript = preload(
	"res://scripts/combat/gt1_rival_combat_snapshot_provider.gd"
)

const GT1_MONTHS := [13, 16, 20]
const CANONICAL_RIVAL_TEAM_ID := "rival_team"
const BOUT_COUNT := 3

var _arena_runtime = CombatV1ArenaRuntimeScript.new()
var _rival_provider = GT1RivalCombatSnapshotProviderScript.new()


func get_gt1_setup_catalog(month: int) -> Dictionary:
	if not GT1_MONTHS.has(month):
		return _rejected(
			"unsupported_gt1_month",
			["Player-facing GT I setup only supports months XIII, XVI and XX"],
		)
	var rivals: Array[Dictionary] = []
	for raw_ludus in DataRepository.get_rival_ludi():
		if not raw_ludus is Dictionary:
			return _rejected(
				"invalid_rival_catalog", ["Canonical rival Ludus catalog contains an invalid entry"]
			)
		var ludus := raw_ludus as Dictionary
		var rival_id := str(ludus.get("id", ""))
		var profiles := _get_rival_profiles(rival_id)
		if profiles.get("status") != "ready":
			return profiles
		(
			rivals
			. append(
				{
					"id": rival_id,
					"name": str(ludus.get("name", rival_id)),
					"fighters": (profiles.get("fighters", []) as Array).duplicate(true),
				}
			)
		)
	var beasts: Array[Dictionary] = []
	if month == 16:
		var beast_readiness := _arena_runtime.get_month_16_beast_readiness()
		if beast_readiness.get("beast_selection_ready") != true:
			return _rejected(
				"beast_catalog_not_ready",
				["Month XVI canonical beast catalog is not ready for player-facing setup"],
			)
		for raw_beast in DataRepository.beasts:
			if not raw_beast is Dictionary:
				return _rejected(
					"invalid_beast_catalog", ["Canonical beast catalog contains an invalid entry"]
				)
			var beast := raw_beast as Dictionary
			(
				beasts
				. append(
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


func prepare_month_13_request(
	player_gladiator_id: String,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids: Array
) -> Dictionary:
	var resolved := _resolve_rival_singles(rival_ludus_id, rival_fighter_ids)
	if resolved.get("status") != "ready":
		return resolved
	return (
		_arena_runtime
		. prepare_month_13_request(
			player_gladiator_id,
			player_team_id,
			resolved.get("fighters", []) as Array,
		)
	)


func start_month_13_session(
	player_gladiator_id: String,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids: Array
) -> Dictionary:
	return _start_prepared(
		prepare_month_13_request(
			player_gladiator_id, player_team_id, rival_ludus_id, rival_fighter_ids
		)
	)


func prepare_month_16_human_request(
	player_gladiator_ids: Array,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids: Array
) -> Dictionary:
	var resolved := _resolve_rival_singles(rival_ludus_id, rival_fighter_ids)
	if resolved.get("status") != "ready":
		return resolved
	return (
		_arena_runtime
		. prepare_month_16_human_request(
			player_gladiator_ids,
			player_team_id,
			resolved.get("fighters", []) as Array,
		)
	)


func start_month_16_human_session(
	player_gladiator_ids: Array,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids: Array
) -> Dictionary:
	return _start_prepared(
		prepare_month_16_human_request(
			player_gladiator_ids, player_team_id, rival_ludus_id, rival_fighter_ids
		)
	)


func start_month_16_beast_session(
	player_gladiator_ids: Array, player_team_id: String, beast_ids: Array, opponent_team_id: String
) -> Dictionary:
	return _arena_runtime.start_month_16_beast_session(
		player_gladiator_ids, player_team_id, beast_ids, opponent_team_id
	)


func prepare_month_20_request(
	player_ids_by_bout: Array,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids_by_bout: Array
) -> Dictionary:
	var resolved := _resolve_rival_pairs(rival_ludus_id, rival_fighter_ids_by_bout)
	if resolved.get("status") != "ready":
		return resolved
	return (
		_arena_runtime
		. prepare_month_20_request(
			player_ids_by_bout,
			player_team_id,
			resolved.get("fighters_by_bout", []) as Array,
		)
	)


func start_month_20_session(
	player_ids_by_bout: Array,
	player_team_id: String,
	rival_ludus_id: String,
	rival_fighter_ids_by_bout: Array
) -> Dictionary:
	return _start_prepared(
		prepare_month_20_request(
			player_ids_by_bout,
			player_team_id,
			rival_ludus_id,
			rival_fighter_ids_by_bout,
		)
	)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"setup_authority": "gt1_series_setup_runtime",
		"combat_runtime": "combat_v1_arena_runtime",
		"human_opponent_selection_authority": "gt1_rival_combat_snapshot_provider",
		"rival_catalog": "DataRepository.rival_combat_v1_snapshots",
		"rival_ludi": "DataRepository.rival_ludi",
		"month_16_beast_catalog": "DataRepository.beasts",
		"canonical_rival_team_id": CANONICAL_RIVAL_TEAM_ID,
		"explicit_series_selection_required": true,
		"generated_opponents_allowed": false,
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"save_version_change_required": false,
	}


func _get_rival_profiles(rival_ludus_id: String) -> Dictionary:
	var entries := DataRepository.get_rival_combat_v1_snapshots_for_ludus(rival_ludus_id)
	if entries.is_empty():
		return _rejected(
			"rival_profiles_unavailable",
			["No canonical Combat V1 profiles are available for %s" % rival_ludus_id],
		)
	var fighters: Array[Dictionary] = []
	var seen_ids: Array[String] = []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			return _rejected(
				"invalid_rival_catalog",
				["Canonical rival snapshot catalog contains an invalid entry"],
			)
		var fighter_value: Variant = (raw_entry as Dictionary).get("fighter", {})
		if not fighter_value is Dictionary:
			return _rejected(
				"invalid_rival_catalog", ["Canonical rival snapshot entry is missing fighter data"]
			)
		var fighter_id := str((fighter_value as Dictionary).get("id", ""))
		if fighter_id.is_empty() or seen_ids.has(fighter_id):
			return _rejected(
				"invalid_rival_catalog",
				["Canonical rival profile ids must be non-empty and unique"],
			)
		seen_ids.append(fighter_id)
		var resolved := _rival_provider.get_snapshot(
			rival_ludus_id, fighter_id, CANONICAL_RIVAL_TEAM_ID
		)
		if resolved.get("status") != "ready":
			return _rejected(
				str(resolved.get("reason", "invalid_rival_catalog")),
				resolved.get("errors", []) as Array,
			)
		var fighter := resolved.get("fighter_snapshot", {}) as Dictionary
		(
			fighters
			. append(
				{
					"id": fighter_id,
					"stats": (fighter.get("stats", {}) as Dictionary).duplicate(true),
					"stamina": fighter.get("stamina"),
				}
			)
		)
	fighters.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.id) < str(b.id))
	return {"status": "ready", "reason": "", "errors": [], "fighters": fighters}


func _resolve_rival_singles(rival_ludus_id: String, fighter_ids: Array) -> Dictionary:
	if fighter_ids.size() != BOUT_COUNT:
		return _rejected(
			"invalid_rival_series_selection",
			["GT I 1v1 setup requires exactly three explicit rival fighter selections"],
		)
	var fighters: Array = []
	for fighter_value in fighter_ids:
		var resolved := _rival_provider.get_snapshot(
			rival_ludus_id, str(fighter_value), CANONICAL_RIVAL_TEAM_ID
		)
		if resolved.get("status") != "ready":
			return _rejected(
				str(resolved.get("reason", "rival_combat_snapshot_unavailable")),
				resolved.get("errors", []) as Array,
			)
		fighters.append((resolved.get("fighter_snapshot", {}) as Dictionary).duplicate(true))
	return {"status": "ready", "reason": "", "errors": [], "fighters": fighters}


func _resolve_rival_pairs(rival_ludus_id: String, fighter_ids_by_bout: Array) -> Dictionary:
	if fighter_ids_by_bout.size() != BOUT_COUNT:
		return _rejected(
			"invalid_rival_series_selection",
			["GT I 2v2 setup requires exactly three explicit rival pair selections"],
		)
	var fighters_by_bout: Array = []
	for index in range(fighter_ids_by_bout.size()):
		var raw_pair: Variant = fighter_ids_by_bout[index]
		if not raw_pair is Array or (raw_pair as Array).size() != 2:
			return _rejected(
				"invalid_rival_series_selection",
				["GT I month XX rival bout %d requires exactly two profile ids" % [index + 1]],
			)
		var pair: Array = []
		for raw_id in raw_pair as Array:
			var resolved := _rival_provider.get_snapshot(
				rival_ludus_id, str(raw_id), CANONICAL_RIVAL_TEAM_ID
			)
			if resolved.get("status") != "ready":
				return _rejected(
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


func _start_prepared(request: Dictionary) -> Dictionary:
	if request.get("status") != "ready":
		return request
	return (
		_arena_runtime
		. start_gt1_session(
			int(request.get("month", 0)),
			str(request.get("player_team_id", "")),
			request.get("player_ids_by_bout", []) as Array,
			request.get("opponent_fighters_by_bout", []) as Array,
		)
	)


func _rejected(reason: String, errors: Array) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"generated_opponents_allowed": false,
	}
