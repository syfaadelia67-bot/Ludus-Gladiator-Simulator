extends Node

const GT1ChampionshipTiebreakRuntimeScript = preload(
	"res://scripts/combat/gt1_championship_tiebreak_runtime.gd"
)


func _ready() -> void:
	_test_unavailable_player_gladiator_is_rejected()
	_test_explicit_rival_team_mismatch_is_rejected()
	_test_authoritative_combat_resolves_championship_without_points()
	_test_contract()
	TournamentManager.import_state({})
	print("GT I championship tiebreak runtime: OK")
	get_tree().quit(0)


func _test_unavailable_player_gladiator_is_rejected() -> void:
	_seed_exact_championship_tie()
	var runtime = GT1ChampionshipTiebreakRuntimeScript.new()
	var player := _player_person()
	player.injury_days = 1
	var result := runtime.start_from_sources(
		player,
		{"power": 100, "defense": 0},
		"alpha",
		"beta",
		_rival_fighter("beta"),
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "invalid_tiebreak_sources")
	assert((result.get("errors", []) as Array).has("Selected player gladiator is not available for combat"))


func _test_explicit_rival_team_mismatch_is_rejected() -> void:
	_seed_exact_championship_tie()
	var runtime = GT1ChampionshipTiebreakRuntimeScript.new()
	var result := runtime.start_from_sources(
		_player_person(),
		{"power": 100, "defense": 0},
		"alpha",
		"beta",
		_rival_fighter("gamma"),
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "invalid_tiebreak_sources")
	assert(
		(result.get("errors", []) as Array).has(
			"Rival Combat V1 snapshot must use the declared rival team id"
		)
	)


func _test_authoritative_combat_resolves_championship_without_points() -> void:
	_seed_exact_championship_tie()
	var runtime = GT1ChampionshipTiebreakRuntimeScript.new()
	var session := runtime.start_from_sources(
		_player_person(),
		{"power": 100, "defense": 0},
		"alpha",
		"beta",
		_rival_fighter("beta"),
	)
	assert(session.get("status") == "tiebreak_combat_running")
	assert(session.get("rival_ludus_id") == "cassianus")
	assert(session.get("rival_source") == "explicit_external_combat_v1_snapshot")
	assert(session.get("team_to_ludus") == {"alpha": "player", "beta": "cassianus"})

	var result := (
		runtime
		. advance_exchange(
			session,
			[
				{"actor_id": "champion", "action_id": "heavy", "target_id": "rival_glad"},
				{"actor_id": "rival_glad", "action_id": "block"},
			],
		)
	)
	assert(result.get("status") == "tiebreak_resolved")
	var combat_result := result.get("last_combat_result", {}) as Dictionary
	assert(combat_result.get("status") == "combat_finished")
	assert(combat_result.get("outcome") == "team_win")
	assert(combat_result.get("winner_team_id") == "alpha")
	var resolution := result.get("standings_resolution", {}) as Dictionary
	assert(resolution.get("status") == "resolved")
	assert(resolution.get("resolution_source") == "tournament_characteristic_combat")
	assert(resolution.get("applied_to_tournament_manager") == true)
	assert(int(resolution.get("points_awarded", -1)) == 0)

	var summary := TournamentManager.get_gt1_summary()
	assert(summary.get("standings_resolved") == true)
	assert(summary.get("tiebreak_required") == false)
	assert(int(summary.get("placement", 0)) == 1)
	assert(summary.get("medal") == "gold")
	assert(int(summary.get("player_points", 0)) == 27)
	assert(int(summary.get("player_wins", 0)) == 9)


func _test_contract() -> void:
	var runtime = GT1ChampionshipTiebreakRuntimeScript.new()
	var contract := runtime.get_contract()
	assert(contract.get("supported_tie") == "two_ludi_tied_first_at_27_points")
	assert(contract.get("format") == "1v1")
	assert(contract.get("player_selection") == "one_available_gladiator")
	assert(contract.get("player_availability") == "LudusPerson.is_available_for_combat")
	assert(contract.get("player_source") == "RosterManager.get_person")
	assert(contract.get("equipment_source") == "EquipmentManager.get_equipped_stats")
	assert(contract.get("rival_source") == "explicit_external_combat_v1_snapshot")
	assert(contract.get("rival_generation_allowed") == false)
	assert(contract.get("combat_runtime") == "Combat1v1Loop")
	assert(contract.get("combat_result_authority") == "CombatSimulator")
	assert(contract.get("standings_authority") == "TournamentManager")
	assert(contract.get("points_awarded") == 0)
	assert(contract.get("save_version_change_required") == false)


func _seed_exact_championship_tie() -> void:
	(
		TournamentManager
		. import_state(
			{
				"gt1_player_points": 27,
				"gt1_player_wins": 9,
				"gt1_player_bouts": 9,
				"gt1_encounter_progress": {"13": 3, "16": 3, "20": 3},
			}
		)
	)
	var rival_results := [
		["cassianus", "Ludus Cassianus", 27, 9],
		["aurelius", "Ludus Aurelius", 24, 8],
		["flavianus", "Ludus Flavianus", 21, 7],
		["drusus", "Ludus Drusus", 18, 6],
		["severus", "Ludus Severus", 15, 5],
		["marcellus", "Ludus Marcellus", 12, 4],
		["varro", "Ludus Varro", 9, 3],
	]
	for rival_result in rival_results:
		assert(
			TournamentManager.register_gt1_rival_result(
				str(rival_result[0]),
				str(rival_result[1]),
				int(rival_result[2]),
				int(rival_result[3]),
			)
		)
	var summary := TournamentManager.get_gt1_summary()
	assert(summary.get("standings_resolved") == false)
	assert(summary.get("tiebreak_required") == true)


func _player_person() -> LudusPerson:
	return LudusPerson.new(
		{
			"id": "champion",
			"name": "Champion",
			"role": "gladiator",
			"strength": 10,
			"agility": 10,
			"technique": 20,
			"resistance": 10,
			"health": 20,
			"fatigue": 0,
			"injury_days": 0,
		}
	)


func _rival_fighter(team_id: String) -> Dictionary:
	return {
		"id": "rival_glad",
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 5, "PV": 5},
		"stamina": 10,
		"equipment": {"power": 0, "defense": 0},
	}
