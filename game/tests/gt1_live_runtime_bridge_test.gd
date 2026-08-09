extends Node

const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")


func run() -> void:
	_test_live_roster_starts_authoritative_gt1_runtime()
	_test_live_roster_failure_is_preserved_by_runtime()
	print("GT I live roster runtime bridge tests passed")


func _test_live_roster_starts_authoritative_gt1_runtime() -> void:
	TournamentManager.import_state({})
	if RosterManager.get_people().is_empty():
		RosterManager._seed_initial_roster()
	var person = RosterManager.get_people()[0]
	assert(person != null)
	var original_role := str(person.role)
	person.role = "gladiator"
	var player_id := str(person.id)

	var runtime = GT1CombatRuntimeScript.new()
	var session: Dictionary = (
		runtime
		. start_encounter_from_live_roster(
			13,
			"player_team",
			[[player_id], [player_id], [player_id]],
			[
				[_opponent("live_rival_1")],
				[_opponent("live_rival_2")],
				[_opponent("live_rival_3")],
			],
		)
	)

	assert(session.get("status") == "combat_running")
	assert(session.get("combat_state_source") == "live_roster_and_equipment_snapshots")
	assert(session.get("opponent_source") == "explicit_external_combat_v1_snapshots")
	var templates := session.get("bout_templates", []) as Array
	assert(templates.size() == 3)
	var player_fighter := _fighter_by_id(templates[0] as Dictionary, player_id)
	assert(not player_fighter.is_empty())
	assert(
		(player_fighter.get("equipment", {}) as Dictionary)
		== EquipmentManager.get_equipped_stats(person)
	)
	assert(
		int((player_fighter.get("stats", {}) as Dictionary).get("RES", -1))
		== int(person.resistance)
	)

	var contract: Dictionary = runtime.get_contract()
	assert(contract.get("live_roster_start") == "GT1LiveRosterStateBuilder.build_from_live_roster")
	assert(contract.get("live_player_source") == "RosterManager.get_gladiators")
	assert(contract.get("live_equipment_source") == "EquipmentManager.get_equipped_stats")
	assert(contract.get("live_opponent_source") == "explicit_external_combat_v1_snapshots")

	person.role = original_role
	TournamentManager.import_state({})


func _test_live_roster_failure_is_preserved_by_runtime() -> void:
	TournamentManager.import_state({})
	var runtime = GT1CombatRuntimeScript.new()
	var result: Dictionary = (
		runtime
		. start_encounter_from_live_roster(
			13,
			"player_team",
			[["missing"], ["missing"], ["missing"]],
			[
				[_opponent("missing_rival_1")],
				[_opponent("missing_rival_2")],
				[_opponent("missing_rival_3")],
			],
		)
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "gt1_live_roster_build_failed")
	assert(_contains_error(result, "unavailable gladiator missing"))
	TournamentManager.import_state({})


func _opponent(fighter_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": "rival_team",
		"stats": {"FUE": 8, "AGI": 8, "TEC": 8, "RES": 8, "PV": 30},
		"stamina": 10.0,
		"equipment": {"power": 0, "defense": 0},
	}


func _fighter_by_id(state: Dictionary, fighter_id: String) -> Dictionary:
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("id", "")) == fighter_id:
			return fighter
	return {}


func _contains_error(result: Dictionary, fragment: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
