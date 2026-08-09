extends RefCounted

const Combat1v1LoopScript = preload("res://scripts/combat/combat_1v1_loop.gd")
const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatRosterFighterAdapterScript = preload(
	"res://scripts/combat/combat_roster_fighter_adapter.gd"
)
const GT1RivalCombatSnapshotContractScript = preload(
	"res://scripts/combat/gt1_rival_combat_snapshot_contract.gd"
)
const GT1RivalResultRegistryScript = preload("res://scripts/combat/gt1_rival_result_registry.gd")

var _loop = Combat1v1LoopScript.new()
var _combat_contract = CombatContractScript.new()
var _fighter_adapter = CombatRosterFighterAdapterScript.new()
var _registry = GT1RivalResultRegistryScript.new()
var _rival_snapshot_contract = GT1RivalCombatSnapshotContractScript.new()


func start_from_live_roster(
	player_gladiator_id: String,
	player_team_id: String,
	rival_team_id: String,
	rival_fighter_snapshot: Dictionary
) -> Dictionary:
	var person = RosterManager.get_person(player_gladiator_id)
	if person == null:
		return _rejected("unknown_player_gladiator", ["Selected player gladiator does not exist"])
	var equipment_stats = EquipmentManager.get_equipped_stats(person)
	if not equipment_stats is Dictionary:
		return _rejected(
			"invalid_equipment_snapshot",
			["EquipmentManager did not return Combat V1 equipment stats"],
		)
	return start_from_sources(
		person,
		equipment_stats as Dictionary,
		player_team_id,
		rival_team_id,
		rival_fighter_snapshot,
	)


func start_from_sources(
	player_person,
	player_equipment_stats: Dictionary,
	player_team_id: String,
	rival_team_id: String,
	rival_fighter_snapshot: Dictionary
) -> Dictionary:
	var request := _registry.build_podium_tiebreak_request()
	if request.get("status") != "ready":
		return _rejected(
			"championship_tiebreak_not_ready",
			request.get("errors", []) as Array,
			request,
		)

	var source_errors := _validate_sources(
		player_person,
		player_team_id,
		rival_team_id,
		rival_fighter_snapshot,
	)
	if not source_errors.is_empty():
		return _rejected("invalid_tiebreak_sources", source_errors, request)

	var rival_snapshot_validation := (
		_rival_snapshot_contract
		. validate(
			str(request.get("rival_ludus_id", "")),
			rival_team_id,
			rival_fighter_snapshot,
		)
	)
	if rival_snapshot_validation.get("status") != "ready":
		return _rejected(
			"invalid_rival_combat_snapshot",
			rival_snapshot_validation.get("errors", []) as Array,
			request,
		)

	var player_build := (
		_fighter_adapter
		. build_from_person(
			player_person,
			player_team_id,
			player_equipment_stats,
		)
	)
	if player_build.get("status") != "ready":
		var build_errors := player_build.get("errors", []) as Array
		if build_errors.is_empty():
			build_errors = ["Selected player gladiator could not build a Combat V1 snapshot"]
		return _rejected("player_combat_snapshot_failed", build_errors, request)

	var player_fighter := (player_build.get("fighter", {}) as Dictionary).duplicate(true)
	var rival_fighter := (
		(rival_snapshot_validation.get("fighter_snapshot", {}) as Dictionary).duplicate(true)
	)
	var state := {
		"format": "1v1",
		"fighters": [player_fighter, rival_fighter],
	}
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected("invalid_tiebreak_combat_state", state_errors, request)

	var loop_state := _loop.start(state)
	if loop_state.get("status") != "running":
		return _rejected(
			"tiebreak_combat_start_failed",
			loop_state.get("errors", []) as Array,
			request,
		)

	var rival_ludus_id := str(request.get("rival_ludus_id", ""))
	return {
		"status": "tiebreak_combat_running",
		"reason": "",
		"errors": [],
		"request": request.duplicate(true),
		"player_gladiator_id": str(player_person.id),
		"rival_fighter_id": str(rival_fighter.get("id", "")),
		"player_team_id": player_team_id,
		"rival_team_id": rival_team_id,
		"rival_ludus_id": rival_ludus_id,
		"team_to_ludus": {player_team_id: "player", rival_team_id: rival_ludus_id},
		"active_loop": loop_state.duplicate(true),
		"last_combat_result": {},
		"standings_resolution": {},
		"player_source":
		(
			"live_roster_and_equipment"
			if player_person == RosterManager.get_person(str(player_person.id))
			else "explicit_test_source"
		),
		"rival_source": str(rival_snapshot_validation.get("snapshot_source", "")),
		"rival_snapshot_validation": rival_snapshot_validation.duplicate(true),
	}


func advance_exchange(session: Dictionary, intents: Array) -> Dictionary:
	if str(session.get("status", "")) != "tiebreak_combat_running":
		return _rejected(
			"invalid_tiebreak_session",
			["Championship tiebreak session must be running before advance"],
			session.get("request", {}) as Dictionary,
		)
	var active_loop := session.get("active_loop", {}) as Dictionary
	var combat_result: Dictionary = _loop.advance(active_loop, intents)
	if combat_result.get("status") == "rejected":
		return _rejected(
			str(combat_result.get("reason", "tiebreak_combat_advance_failed")),
			combat_result.get("errors", []) as Array,
			session.get("request", {}) as Dictionary,
		)

	var next := session.duplicate(true)
	next["active_loop"] = combat_result.duplicate(true)
	next["last_combat_result"] = combat_result.duplicate(true)
	if combat_result.get("status") != "combat_finished":
		return next

	var standings_resolution := (
		_registry
		. resolve_podium_tiebreak(
			combat_result,
			session.get("team_to_ludus", {}) as Dictionary,
		)
	)
	next["standings_resolution"] = standings_resolution.duplicate(true)
	next["active_loop"] = {}
	if standings_resolution.get("status") == "rematch_required":
		next["status"] = "rematch_required"
		return next
	if (
		standings_resolution.get("status") != "resolved"
		or standings_resolution.get("applied_to_tournament_manager") != true
	):
		return _rejected(
			"tiebreak_standings_resolution_failed",
			standings_resolution.get("errors", []) as Array,
			session.get("request", {}) as Dictionary,
		)
	next["status"] = "tiebreak_resolved"
	return next


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"supported_tie": "two_ludi_tied_first_at_27_points",
		"format": "1v1",
		"player_selection": "one_available_gladiator",
		"player_availability": "LudusPerson.is_available_for_combat",
		"player_source": "RosterManager.get_person",
		"equipment_source": "EquipmentManager.get_equipped_stats",
		"rival_source": "explicit_external_combat_v1_snapshot",
		"rival_validation_contract": "gt1_rival_combat_snapshot_contract",
		"rival_generation_allowed": false,
		"combat_runtime": "Combat1v1Loop",
		"combat_result_authority": "CombatSimulator",
		"standings_authority": "TournamentManager",
		"points_awarded": 0,
		"double_ko": "rematch_required",
		"save_version_change_required": false,
	}


func _validate_sources(
	player_person, player_team_id: String, rival_team_id: String, rival_fighter_snapshot: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	if player_person == null:
		errors.append("Championship tiebreak requires a player gladiator")
	elif str(player_person.role) != "gladiator":
		errors.append("Championship tiebreak player selection must be a gladiator")
	elif not player_person.is_available_for_combat():
		errors.append("Selected player gladiator is not available for combat")
	if player_team_id.is_empty() or rival_team_id.is_empty():
		errors.append("Championship tiebreak requires two non-empty team ids")
	elif player_team_id == rival_team_id:
		errors.append("Championship tiebreak teams must be distinct")
	if (
		player_person != null
		and not rival_fighter_snapshot.is_empty()
		and str(rival_fighter_snapshot.get("id", "")) == str(player_person.id)
	):
		errors.append("Championship tiebreak fighters must have distinct ids")
	return errors


func _rejected(reason: String, errors: Array, request: Dictionary = {}) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"request": request.duplicate(true),
		"active_loop": {},
		"last_combat_result": {},
		"standings_resolution": {},
	}
