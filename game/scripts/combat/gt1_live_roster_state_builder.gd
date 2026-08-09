extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatRosterFighterAdapterScript = preload(
	"res://scripts/combat/combat_roster_fighter_adapter.gd"
)
const GT1RosterSelectionContractScript = preload(
	"res://scripts/combat/gt1_roster_selection_contract.gd"
)

const GT1_MONTHS := [13, 16, 20]
const BOUT_COUNT := 3

var _combat_contract = CombatContractScript.new()
var _fighter_adapter = CombatRosterFighterAdapterScript.new()
var _selection_contract = GT1RosterSelectionContractScript.new()


func build_from_live_roster(
	month: int, player_team_id: String, player_ids_by_bout: Array, opponent_fighters_by_bout: Array
) -> Dictionary:
	var people_by_id: Dictionary = {}
	var equipment_by_id: Dictionary = {}
	for person in RosterManager.get_gladiators():
		var person_id := str(person.id)
		people_by_id[person_id] = person
		equipment_by_id[person_id] = EquipmentManager.get_equipped_stats(person).duplicate(true)
	return build_from_sources(
		month,
		player_team_id,
		player_ids_by_bout,
		opponent_fighters_by_bout,
		people_by_id,
		equipment_by_id,
	)


func build_from_sources(
	month: int,
	player_team_id: String,
	player_ids_by_bout: Array,
	opponent_fighters_by_bout: Array,
	people_by_id: Dictionary,
	equipment_by_id: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	if not GT1_MONTHS.has(month):
		errors.append("GT I live roster builder requires month 13, 16 or 20")
	if player_team_id.is_empty():
		errors.append("GT I live roster builder requires player_team_id")
	if opponent_fighters_by_bout.size() != BOUT_COUNT:
		errors.append("GT I live roster builder requires three opponent bout snapshots")

	var available_ids: Array[String] = []
	for raw_id in people_by_id.keys():
		var person = people_by_id[raw_id]
		if person != null and str(person.role) == "gladiator":
			available_ids.append(str(raw_id))
	available_ids.sort()
	errors.append_array(
		_selection_contract.validate_selection(month, player_ids_by_bout, available_ids)
	)
	if not errors.is_empty():
		return _invalid(errors)

	var expected_format := "2v2" if month == 20 else "1v1"
	var expected_opponent_count := 2 if month == 20 else 1
	var bout_states: Array = []
	for index in range(BOUT_COUNT):
		var fighters: Array = []
		for raw_player_id in player_ids_by_bout[index] as Array:
			var player_id := str(raw_player_id)
			var person = people_by_id.get(player_id)
			var equipment := equipment_by_id.get(player_id, {}) as Dictionary
			var adapted: Dictionary = _fighter_adapter.build_from_person(
				person, player_team_id, equipment
			)
			if adapted.get("status") != "ready":
				errors.append(
					"GT I player fighter %s could not build a Combat V1 snapshot" % player_id
				)
				continue
			fighters.append((adapted.get("fighter", {}) as Dictionary).duplicate(true))

		if not opponent_fighters_by_bout[index] is Array:
			errors.append("GT I bout %d opponent snapshot must be an Array" % [index + 1])
			continue
		var opponents := opponent_fighters_by_bout[index] as Array
		if opponents.size() != expected_opponent_count:
			errors.append(
				(
					"GT I bout %d requires exactly %d opponent fighter(s)"
					% [index + 1, expected_opponent_count]
				)
			)
			continue
		for raw_opponent in opponents:
			if not raw_opponent is Dictionary:
				errors.append("GT I opponent fighters must be Combat V1 Dictionaries")
				continue
			fighters.append((raw_opponent as Dictionary).duplicate(true))

		var state := {"format": expected_format, "fighters": fighters}
		var state_errors: Array[String] = _combat_contract.validate_state(state)
		if not state_errors.is_empty():
			for state_error in state_errors:
				errors.append("GT I bout %d: %s" % [index + 1, state_error])
		bout_states.append(state)

	if not errors.is_empty():
		return _invalid(errors)
	return {
		"status": "ready",
		"errors": [],
		"month": month,
		"format": expected_format,
		"player_team_id": player_team_id,
		"bout_states": bout_states.duplicate(true),
		"source": "live_roster_and_equipment_snapshots",
		"opponent_source": "explicit_external_combat_v1_snapshots",
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"player_source": "RosterManager.get_gladiators",
		"equipment_source": "EquipmentManager.get_equipped_stats_snapshot",
		"fighter_adapter": "CombatRosterFighterAdapter.build_from_person",
		"opponent_source": "explicit_external_combat_v1_snapshots",
		"rival_generation_allowed": false,
		"month_13_format": "1v1",
		"month_16_format": "1v1",
		"month_20_format": "2v2",
		"save_version_change_required": false,
	}


func _invalid(errors: Array[String]) -> Dictionary:
	return {
		"status": "invalid",
		"errors": errors.duplicate(),
		"month": 0,
		"format": "",
		"player_team_id": "",
		"bout_states": [],
		"source": "",
		"opponent_source": "",
	}
