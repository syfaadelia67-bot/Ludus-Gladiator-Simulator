extends Node

const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")
const GT1ChampionshipTiebreakRuntimeScript = preload(
	"res://scripts/combat/gt1_championship_tiebreak_runtime.gd"
)


func run() -> void:
	DataRepository.load_all()
	assert(NewCampaignCoordinator.reset_campaign_state())
	assert(GameState.get_month() == 1)
	assert(int(TournamentManager.get_gt1_summary().get("player_bouts", -1)) == 0)
	assert(not CampaignManager.campaign_over)

	_run_month_13_combat_v1()
	_run_month_16_combat_v1()
	_run_month_20_combat_v1()

	var combat_summary := TournamentManager.get_gt1_summary()
	assert(int(combat_summary.get("player_bouts", 0)) == 9)
	assert(int(combat_summary.get("player_wins", 0)) == 9)
	assert(int(combat_summary.get("player_points", 0)) == 27)
	assert(combat_summary.get("encounter_progress") == {"13": 3, "16": 3, "20": 3})

	_register_explicit_rival_result_fixtures()
	var pending := TournamentManager.get_gt1_summary()
	assert(bool(pending.get("tiebreak_required", false)))
	assert(not bool(pending.get("standings_resolved", true)))
	assert(not CampaignManager.campaign_over)

	_run_authoritative_championship_tiebreak()
	var resolved := TournamentManager.get_gt1_summary()
	assert(bool(resolved.get("standings_resolved", false)))
	assert(not bool(resolved.get("tiebreak_required", true)))
	assert(int(resolved.get("placement", 0)) == 1)
	assert(str(resolved.get("medal", "")) == "gold")
	assert(int(resolved.get("player_points", 0)) == 27)
	assert(int(resolved.get("player_bouts", 0)) == 9)
	assert(CampaignManager.campaign_over)
	assert(CampaignManager.final_combat_resolved)
	assert(CampaignManager.victory_achieved)

	var final_summary := CampaignManager.get_summary()
	var finale := final_summary.get("finale", {}) as Dictionary
	assert(bool(finale.get("can_finalize", false)))
	assert(str(finale.get("result_source", "")) == "gt1_classification")
	assert(int(finale.get("placement", 0)) == 1)
	assert(str(finale.get("medal", "")) == "gold")

	var payload := SaveManager._build_payload()
	assert(int(payload.get("version", 0)) == 14)
	assert(SaveManager._validate_payload(payload))
	assert(NewCampaignCoordinator.reset_campaign_state())
	assert(GameState.get_month() == 1)
	assert(not CampaignManager.campaign_over)
	assert(SaveManager._apply_payload(payload))

	assert(GameState.get_month() == 20)
	assert(TournamentManager.is_gt1_complete())
	assert(CampaignManager.campaign_over)
	assert(CampaignManager.final_combat_resolved)
	assert(CampaignManager.victory_achieved)
	var restored := CampaignManager.get_summary()
	var restored_finale := restored.get("finale", {}) as Dictionary
	assert(int(restored_finale.get("placement", 0)) == 1)
	assert(str(restored_finale.get("medal", "")) == "gold")
	assert(str(restored_finale.get("result_source", "")) == "gt1_classification")

	assert(NewCampaignCoordinator.reset_campaign_state())
	print("Demo placeholder end-to-end: New Campaign -> 9 GT I bouts -> tiebreak -> finale -> Save v14 load: OK")


func _run_month_13_combat_v1() -> void:
	_fast_forward_fixture_to_month(13)
	var states: Array = [
		_state_1v1("m13_player", "m13_rival_1"),
		_state_1v1("m13_player", "m13_rival_2"),
		_state_1v1("m13_player", "m13_rival_3"),
	]
	_run_1v1_encounter(13, states, ["m13_player", "m13_player", "m13_player"])


func _run_month_16_combat_v1() -> void:
	_fast_forward_fixture_to_month(16)
	var states: Array = [
		_state_1v1("m16_player_1", "m16_rival_1"),
		_state_1v1("m16_player_2", "m16_rival_2"),
		_state_1v1("m16_player_3", "m16_rival_3"),
	]
	_run_1v1_encounter(16, states, ["m16_player_1", "m16_player_2", "m16_player_3"])


func _run_month_20_combat_v1() -> void:
	_fast_forward_fixture_to_month(20)
	var runtime = GT1CombatRuntimeScript.new()
	var states: Array = [
		_state_2v2(["m20_p1", "m20_p2"], ["m20_r1a", "m20_r1b"]),
		_state_2v2(["m20_p1", "m20_p3"], ["m20_r2a", "m20_r2b"]),
		_state_2v2(["m20_p1", "m20_p3"], ["m20_r3a", "m20_r3b"]),
	]
	var session: Dictionary = runtime.start_encounter(20, "player_team", states)
	assert(session.get("status") == "combat_running")
	assert(bool(session.get("substitution_used", false)))

	for bout in range(3):
		var player_ids: Array[String] = ["m20_p1", "m20_p2"]
		if bout > 0:
			player_ids = ["m20_p1", "m20_p3"]
		var enemy_ids: Array[String] = [
			"m20_r%da" % [bout + 1],
			"m20_r%db" % [bout + 1],
		]
		session = (
			runtime
			. advance_exchange(
				session,
				[
					{"actor_id": player_ids[0], "action_id": "light", "target_id": enemy_ids[0]},
					{"actor_id": player_ids[1], "action_id": "light", "target_id": enemy_ids[1]},
					{"actor_id": enemy_ids[0], "action_id": "block"},
					{"actor_id": enemy_ids[1], "action_id": "block"},
				],
			)
		)
	assert(session.get("status") == "encounter_finished")
	assert(int(session.get("completed_bouts", 0)) == 3)
	assert(int(session.get("player_wins", 0)) == 3)
	assert(int(session.get("player_points", 0)) == 9)


func _run_1v1_encounter(month: int, states: Array, player_ids: Array[String]) -> void:
	var runtime = GT1CombatRuntimeScript.new()
	var session: Dictionary = runtime.start_encounter(month, "player_team", states)
	assert(session.get("status") == "combat_running")
	for bout in range(3):
		var enemy_id := "m%d_rival_%d" % [month, bout + 1]
		session = (
			runtime
			. advance_exchange(
				session,
				[
					{
						"actor_id": player_ids[bout],
						"action_id": "light",
						"target_id": enemy_id,
					},
					{"actor_id": enemy_id, "action_id": "block"},
				],
			)
		)
	assert(session.get("status") == "encounter_finished")
	assert(int(session.get("completed_bouts", 0)) == 3)
	assert(int(session.get("player_wins", 0)) == 3)
	assert(int(session.get("player_points", 0)) == 9)


func _run_authoritative_championship_tiebreak() -> void:
	var runtime = GT1ChampionshipTiebreakRuntimeScript.new()
	var session := (
		runtime
		. start_from_sources(
			_tiebreak_player(),
			{"power": 100, "defense": 0},
			"player_tiebreak",
			"cassianus_team",
			_tiebreak_rival(),
		)
	)
	assert(session.get("status") == "tiebreak_combat_running")
	assert(session.get("rival_source") == "explicit_external_combat_v1_snapshot")
	var result := (
		runtime
		. advance_exchange(
			session,
			[
				{
					"actor_id": "tiebreak_champion",
					"action_id": "heavy",
					"target_id": "cassianus_fixture_gladiator",
				},
				{"actor_id": "cassianus_fixture_gladiator", "action_id": "block"},
			],
		)
	)
	assert(result.get("status") == "tiebreak_resolved")
	var resolution := result.get("standings_resolution", {}) as Dictionary
	assert(resolution.get("resolution_source") == "tournament_characteristic_combat")
	assert(resolution.get("applied_to_tournament_manager") == true)
	assert(int(resolution.get("points_awarded", -1)) == 0)


func _register_explicit_rival_result_fixtures() -> void:
	# Test-only authored standings data. Production remains fail-closed and no
	# rival score is added to runtime defaults or canonical data files.
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
			(
				TournamentManager
				. register_gt1_rival_result(
					str(rival_result[0]),
					str(rival_result[1]),
					int(rival_result[2]),
					int(rival_result[3]),
				)
			)
		)


func _fast_forward_fixture_to_month(month: int) -> void:
	# Part 20 validates the combat/finale/save quality gate while management
	# balance blockers stay explicit in DemoPreAssetReadiness. This assignment is
	# test-only and cannot become campaign scheduling authority.
	GameState.day = month
	TournamentManager.prepare_month(month, true)
	CampaignManager.evaluate_progress()
	assert(GameState.get_month() == month)


func _state_1v1(player_id: String, enemy_id: String) -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter(player_id, "player_team", 40, 100),
			_fighter(enemy_id, "rival_team", 5, 0),
		],
	}


func _state_2v2(player_ids: Array[String], enemy_ids: Array[String]) -> Dictionary:
	return {
		"format": "2v2",
		"fighters":
		[
			_fighter(player_ids[0], "player_team", 40, 100),
			_fighter(player_ids[1], "player_team", 40, 100),
			_fighter(enemy_ids[0], "rival_team", 5, 0),
			_fighter(enemy_ids[1], "rival_team", 5, 0),
		],
	}


func _fighter(fighter_id: String, team_id: String, pv: int, power: int) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": pv},
		"stamina": 10,
		"equipment": {"power": power, "defense": 0},
	}


func _tiebreak_player() -> LudusPerson:
	return (
		LudusPerson
		. new(
			{
				"id": "tiebreak_champion",
				"name": "Tiebreak Champion",
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
	)


func _tiebreak_rival() -> Dictionary:
	return {
		"id": "cassianus_fixture_gladiator",
		"team": "cassianus_team",
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 5, "PV": 5},
		"stamina": 10,
		"equipment": {"power": 0, "defense": 0},
	}
