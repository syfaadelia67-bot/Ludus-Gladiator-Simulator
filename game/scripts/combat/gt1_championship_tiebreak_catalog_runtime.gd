extends RefCounted

const GT1ChampionshipTiebreakRuntimeScript = preload(
	"res://scripts/combat/gt1_championship_tiebreak_runtime.gd"
)
const GT1RivalCombatSnapshotProviderScript = preload(
	"res://scripts/combat/gt1_rival_combat_snapshot_provider.gd"
)
const GT1RivalResultRegistryScript = preload("res://scripts/combat/gt1_rival_result_registry.gd")

var _runtime = GT1ChampionshipTiebreakRuntimeScript.new()
var _provider = GT1RivalCombatSnapshotProviderScript.new()
var _registry = GT1RivalResultRegistryScript.new()


func start_from_live_roster(
	player_gladiator_id: String,
	player_team_id: String,
	rival_team_id: String,
	rival_fighter_id: String
) -> Dictionary:
	var request := _registry.build_podium_tiebreak_request()
	if request.get("status") != "ready":
		return _rejected(
			"championship_tiebreak_not_ready",
			request.get("errors", []) as Array,
			request,
		)

	var rival_lookup := (
		_provider
		. get_snapshot(
			str(request.get("rival_ludus_id", "")),
			rival_fighter_id,
			rival_team_id,
		)
	)
	if rival_lookup.get("status") != "ready":
		return _rejected(
			str(rival_lookup.get("reason", "rival_combat_snapshot_unavailable")),
			rival_lookup.get("errors", []) as Array,
			request,
			rival_lookup,
		)

	var session := (
		_runtime
		. start_from_live_roster(
			player_gladiator_id,
			player_team_id,
			rival_team_id,
			rival_lookup.get("fighter_snapshot", {}) as Dictionary,
		)
	)
	if session.get("status") == "tiebreak_combat_running":
		session["rival_source"] = str(rival_lookup.get("snapshot_source", ""))
		session["rival_catalog_lookup"] = rival_lookup.duplicate(true)
	return session


func advance_exchange(session: Dictionary, intents: Array) -> Dictionary:
	return _runtime.advance_exchange(session, intents)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"supported_tie": "two_ludi_tied_first_at_27_points",
		"format": "1v1",
		"player_source": "RosterManager.get_person",
		"rival_source": GT1RivalCombatSnapshotProviderScript.CATALOG_PATH,
		"rival_provider": "gt1_rival_combat_snapshot_provider",
		"rival_selection_policy": "explicit_fighter_id_required",
		"rival_availability_policy": "not_inferred_by_provider",
		"rival_generation_allowed": false,
		"legacy_rival_manager_is_combat_authority": false,
		"combat_result_authority": "CombatSimulator",
		"standings_authority": "TournamentManager",
		"save_version_change_required": false,
	}


func _rejected(
	reason: String, errors: Array, request: Dictionary = {}, rival_lookup: Dictionary = {}
) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"request": request.duplicate(true),
		"rival_catalog_lookup": rival_lookup.duplicate(true),
		"active_loop": {},
		"last_combat_result": {},
		"standings_resolution": {},
	}
