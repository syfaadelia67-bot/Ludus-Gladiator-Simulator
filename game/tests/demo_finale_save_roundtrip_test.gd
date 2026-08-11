extends Node


func run() -> void:
	_reset_runtime()
	GameState.day = 20
	_register_player_sweep()
	_register_tied_rival_results()

	var pending := TournamentManager.get_gt1_summary()
	assert(bool(pending.get("tiebreak_required", false)))
	assert(not bool(pending.get("standings_resolved", true)))
	CampaignManager._evaluate_campaign_finale()
	assert(not CampaignManager.campaign_over)
	assert(not CampaignManager.final_combat_resolved)

	CampaignManager.import_state(
		{
			"campaign_over": true,
			"victory": true,
			"final_combat_resolved": true,
			"rank_index": 0,
			"chapter_index": 2,
			"wins": 9,
			"losses": 0,
			"completed_objectives": [],
		}
	)
	assert(not CampaignManager.campaign_over)
	assert(not CampaignManager.final_combat_resolved)
	assert(not CampaignManager.victory_achieved)

	assert(
		TournamentManager.apply_gt1_standings_resolution(
			{
				"status": "resolved",
				"resolution_source": "tournament_characteristic_combat",
				"placement": 1,
				"medal": "gold",
			}
		)
	)
	assert(TournamentManager.is_gt1_complete())
	assert(CampaignManager.campaign_over)
	assert(CampaignManager.final_combat_resolved)
	assert(CampaignManager.victory_achieved)

	var payload := SaveManager._build_payload()
	assert(int(payload.get("version", 0)) == 14)
	assert(SaveManager._validate_payload(payload))
	var metadata := SaveCompatibilityInspector._metadata(payload)
	assert(bool(metadata.get("campaign_over", false)))
	assert(bool(metadata.get("final_combat_resolved", false)))
	assert(bool(metadata.get("gt1_standings_resolved", false)))
	assert(not bool(metadata.get("gt1_tiebreak_required", true)))
	assert(int(metadata.get("gt1_placement", 0)) == 1)
	assert(str(metadata.get("gt1_medal", "")) == "gold")
	assert(int(metadata.get("gt1_player_bouts", 0)) == 9)

	_reset_runtime()
	assert(SaveManager._apply_payload(payload))
	assert(GameState.get_month() == 20)
	assert(TournamentManager.is_gt1_complete())
	assert(CampaignManager.campaign_over)
	assert(CampaignManager.final_combat_resolved)
	assert(CampaignManager.victory_achieved)
	var restored := CampaignManager.get_summary()
	var finale: Dictionary = restored.get("finale", {})
	assert(bool(finale.get("can_finalize", false)))
	assert(int(finale.get("placement", 0)) == 1)
	assert(str(finale.get("medal", "")) == "gold")
	assert(str(finale.get("result_source", "")) == "gt1_classification")

	_reset_runtime()
	print("Demo finale Save v14 roundtrip test passed")


func _register_player_sweep() -> void:
	for month in [13, 16, 20]:
		for _bout in range(3):
			var result := TournamentManager.register_grand_tournament_fight_result(true, month)
			assert(not result.is_empty())


func _register_tied_rival_results() -> void:
	assert(TournamentManager.register_gt1_rival_result("rival_tie", "Rival empate", 27, 9))
	for index in range(6):
		assert(
			TournamentManager.register_gt1_rival_result(
				"rival_%d" % index,
				"Rival %d" % index,
				18 - index * 3,
				6 - index,
			)
		)


func _reset_runtime() -> void:
	CombatV1SessionStore.clear_all()
	TournamentManager.import_state({})
	GameState.day = 1
	CampaignManager.import_state({})
