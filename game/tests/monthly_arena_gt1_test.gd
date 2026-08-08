extends Node


func run() -> void:
	_test_normal_month_schedule()
	_test_grand_tournament_schedule()
	_test_gt1_scoring_and_gold()
	_test_gt1_tie_requires_tiebreak()
	print("Monthly Arena and GT I tests passed")


func _test_normal_month_schedule() -> void:
	var schedule := TournamentManager.get_month_schedule(1)
	assert(schedule.size() >= 2 and schedule.size() <= 3)
	assert(_count_competition(schedule, "underworld") == 1)
	assert(_count_competition(schedule, "official_minor") >= 1)
	assert(_count_competition(schedule, "official_minor") <= 2)
	assert(_count_competition(schedule, "grand_tournament") == 0)

	for event in schedule:
		if str(event.get("competition", "")) != "official_minor":
			continue
		assert(str(event.get("format", "")) in ["1v1", "2v2", "1v2"])
		assert(int(event.get("tournament_tier", 0)) in [1, 2, 3])


func _test_grand_tournament_schedule() -> void:
	for month in [13, 16, 20]:
		var schedule := TournamentManager.get_month_schedule(month)
		assert(schedule.size() == 2)
		assert(_count_competition(schedule, "underworld") == 1)
		assert(_count_competition(schedule, "grand_tournament") == 1)
		assert(_count_competition(schedule, "official_minor") == 0)

	var first := TournamentManager.get_gt1_encounter(13)
	assert(int(first.get("encounter", 0)) == 1)
	assert(str(first.get("format", "")) == "1v1")
	assert(bool(first.get("consecutive", false)))
	assert(bool(first.get("same_roster", false)))
	assert(not bool(first.get("allows_beasts", true)))

	var second := TournamentManager.get_gt1_encounter(16)
	assert(int(second.get("encounter", 0)) == 2)
	assert(str(second.get("format", "")) == "1v1")
	assert(not bool(second.get("consecutive", true)))
	assert(bool(second.get("allows_beasts", false)))

	var finale := TournamentManager.get_gt1_encounter(20)
	assert(int(finale.get("encounter", 0)) == 3)
	assert(str(finale.get("format", "")) == "2v2")
	assert(int(finale.get("team_size", 0)) == 2)
	assert(int(finale.get("substitutions", 0)) == 1)
	assert(int(finale.get("series_bouts", 0)) == 3)


func _test_gt1_scoring_and_gold() -> void:
	TournamentManager.import_state({})
	for month in [13, 16, 20]:
		for _bout in range(3):
			var result := TournamentManager.register_grand_tournament_fight_result(true, month)
			assert(not result.is_empty())

	var summary := TournamentManager.get_gt1_summary()
	assert(int(summary.get("player_bouts", 0)) == 9)
	assert(int(summary.get("player_wins", 0)) == 9)
	assert(int(summary.get("player_points", 0)) == 27)
	assert(bool(summary.get("player_series_complete", false)))
	assert(not bool(summary.get("standings_resolved", true)))

	_register_rivals([24, 21, 18, 15, 12, 9, 6], [8, 7, 6, 5, 4, 3, 2])
	summary = TournamentManager.get_gt1_summary()
	assert(bool(summary.get("standings_resolved", false)))
	assert(int(summary.get("placement", 0)) == 1)
	assert(str(summary.get("medal", "")) == "gold")
	assert(TournamentManager.is_gt1_complete())


func _test_gt1_tie_requires_tiebreak() -> void:
	TournamentManager.import_state({})
	for month in [13, 16, 20]:
		for _bout in range(3):
			TournamentManager.register_grand_tournament_fight_result(true, month)

	_register_rivals([27, 21, 18, 15, 12, 9, 6], [9, 7, 6, 5, 4, 3, 2])
	var summary := TournamentManager.get_gt1_summary()
	assert(bool(summary.get("tiebreak_required", false)))
	assert(not bool(summary.get("standings_resolved", true)))
	assert(int(summary.get("placement", -1)) == 0)
	assert(str(summary.get("medal", "x")).is_empty())
	assert(not TournamentManager.is_gt1_complete())


func _register_rivals(points: Array, wins: Array) -> void:
	for index in range(7):
		var registered := TournamentManager.register_gt1_rival_result(
			"rival_%d" % index,
			"Rival %d" % index,
			int(points[index]),
			int(wins[index]),
		)
		assert(registered)


func _count_competition(schedule: Array, competition: String) -> int:
	var count := 0
	for event in schedule:
		if str(event.get("competition", "")) == competition:
			count += 1
	return count
