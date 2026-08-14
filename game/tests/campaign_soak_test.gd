extends Node

const DEFAULT_CAMPAIGN_COUNT := 10
const MAX_CAMPAIGN_COUNT := 500
const DEMO_FINAL_MONTH := 20
const GT1_MONTHS := [13, 16, 20]
const GT1_BOUTS_PER_ENCOUNTER := 3
const POINTS_PER_WIN := 3
const CAMPAIGN_COUNT_ARGUMENT_PREFIX := "--campaign-count="
const SEED_BASE_ARGUMENT_PREFIX := "--seed-base="


func run() -> void:
	var campaign_count := _get_int_argument(
		CAMPAIGN_COUNT_ARGUMENT_PREFIX, DEFAULT_CAMPAIGN_COUNT, 1, MAX_CAMPAIGN_COUNT
	)
	var seed_base := _get_int_argument(SEED_BASE_ARGUMENT_PREFIX, 41001, 1, 2147483000)
	var failures: Array[String] = []
	var completed := 0
	var total_months_advanced := 0
	var total_events_resolved := 0
	var total_gt1_bouts := 0

	print(
		"CAMPAIGN SOAK START: campaigns=%d · final_month=%d · seed_base=%d"
		% [campaign_count, DEMO_FINAL_MONTH, seed_base]
	)
	for campaign_index in range(campaign_count):
		var campaign_result := _run_campaign(campaign_index, seed_base + campaign_index)
		total_months_advanced += int(campaign_result.get("months_advanced", 0))
		total_events_resolved += int(campaign_result.get("events_resolved", 0))
		total_gt1_bouts += int(campaign_result.get("gt1_bouts", 0))
		var campaign_errors := campaign_result.get("errors", []) as Array
		if campaign_errors.is_empty():
			completed += 1
		else:
			for raw_error in campaign_errors:
				failures.append("campaign=%d seed=%d · %s" % [campaign_index + 1, seed_base + campaign_index, str(raw_error)])

	print(
		(
			"CAMPAIGN SOAK SUMMARY: completed=%d/%d · months_advanced=%d · "
			+ "events_resolved=%d · gt1_bouts=%d · failures=%d"
		)
		% [
			completed,
			campaign_count,
			total_months_advanced,
			total_events_resolved,
			total_gt1_bouts,
			failures.size(),
		]
	)
	if not failures.is_empty():
		for failure in failures:
			push_error("CAMPAIGN SOAK FAILURE: %s" % failure)
	assert(failures.is_empty(), "Campaign soak detected %d failing campaign(s)." % failures.size())
	print("Campaign multi-run headless soak test: OK")


func _run_campaign(campaign_index: int, campaign_seed: int) -> Dictionary:
	var errors: Array[String] = []
	var months_advanced := 0
	var events_resolved := 0
	var gt1_bouts := 0

	seed(campaign_seed)
	if not NewCampaignCoordinator.reset_campaign_state():
		errors.append("new campaign reset failed")
		return _result(errors, months_advanced, events_resolved, gt1_bouts)
	TournamentManager.prepare_month(GameState.get_month(), true)
	CampaignManager.evaluate_progress()

	while not CampaignManager.campaign_over and GameState.get_month() <= DEMO_FINAL_MONTH:
		var month := GameState.get_month()
		var invariant_errors := _validate_invariants(campaign_index, month)
		errors.append_array(invariant_errors)
		if not invariant_errors.is_empty():
			break

		var event_result := _resolve_pending_event()
		if not bool(event_result.get("success", false)):
			errors.append("month %d event blocker: %s" % [month, str(event_result.get("reason", "unknown"))])
			break
		if bool(event_result.get("resolved", false)):
			events_resolved += 1

		if GT1_MONTHS.has(month):
			var encounter_result := _resolve_gt1_encounter(campaign_index, month)
			if not bool(encounter_result.get("success", false)):
				errors.append("month %d GT1 blocker: %s" % [month, str(encounter_result.get("reason", "unknown"))])
				break
			gt1_bouts += int(encounter_result.get("bouts", 0))

		if month == DEMO_FINAL_MONTH:
			var rivals_result := _register_rival_results()
			if not bool(rivals_result.get("success", false)):
				errors.append("month %d rival standings blocker: %s" % [month, str(rivals_result.get("reason", "unknown"))])
				break
			CampaignManager.evaluate_progress()
			if not CampaignManager.campaign_over:
				errors.append("month %d reached finale but campaign did not complete" % month)
			break

		var closure := GameState.get_month_closure_status()
		if not bool(closure.get("can_close", false)):
			errors.append("month %d cannot close: %s" % [month, str(closure.get("blockers", []))])
			break
		var gt_points_before := int(TournamentManager.get_gt1_summary().get("player_points", 0))
		GameState.advance_month()
		months_advanced += 1
		if GameState.get_month() != month + 1:
			errors.append("month progression stalled at %d" % month)
			break
		if not GT1_MONTHS.has(month):
			var gt_points_after := int(TournamentManager.get_gt1_summary().get("player_points", 0))
			if gt_points_after != gt_points_before:
				errors.append("non-GT month %d changed Torneo de Marte points" % month)
				break

	if errors.is_empty():
		if not CampaignManager.campaign_over:
			errors.append("campaign exited soak loop without completing")
		elif GameState.get_month() != DEMO_FINAL_MONTH:
			errors.append("campaign completed on unexpected month %d" % GameState.get_month())
		var gt1_summary := TournamentManager.get_gt1_summary()
		if int(gt1_summary.get("player_bouts", 0)) != 9:
			errors.append("campaign completed with %d/9 GT1 bouts" % int(gt1_summary.get("player_bouts", 0)))
		if not bool(gt1_summary.get("standings_resolved", false)):
			errors.append("campaign completed without resolved GT1 standings")

	return _result(errors, months_advanced, events_resolved, gt1_bouts)


func _resolve_pending_event() -> Dictionary:
	var pending := EventManager.get_pending_event()
	if pending.is_empty():
		return {"success": true, "resolved": false}
	for raw_choice in pending.get("choices", []) as Array:
		if not raw_choice is Dictionary:
			continue
		var choice := raw_choice as Dictionary
		if not EventManager.get_unmet_requirements(choice).is_empty():
			continue
		var resolution := EventManager.resolve_choice(str(choice.get("id", "")))
		if bool(resolution.get("success", false)):
			return {"success": true, "resolved": true}
	return {
		"success": false,
		"resolved": false,
		"reason": "pending event has no valid deterministic choice: %s" % str(pending.get("id", "unknown")),
	}


func _resolve_gt1_encounter(campaign_index: int, month: int) -> Dictionary:
	var summary := TournamentManager.get_gt1_summary()
	var progress := summary.get("encounter_progress", {}) as Dictionary
	var already_resolved := int(progress.get(str(month), 0))
	var global_bout_offset := GT1_MONTHS.find(month) * GT1_BOUTS_PER_ENCOUNTER
	var loss_count := campaign_index % 3
	var resolved := 0
	for local_bout in range(already_resolved, GT1_BOUTS_PER_ENCOUNTER):
		var global_bout := global_bout_offset + local_bout
		var victory := ((global_bout + campaign_index) % 9) >= loss_count
		var result := TournamentManager.register_grand_tournament_fight_result(victory, month)
		if result.is_empty():
			return {"success": false, "reason": "bout %d was rejected" % (local_bout + 1), "bouts": resolved}
		resolved += 1
	return {"success": true, "bouts": resolved}


func _register_rival_results() -> Dictionary:
	var summary := TournamentManager.get_gt1_summary()
	if int(summary.get("rival_results_registered", 0)) == 7:
		return {"success": true}
	var rivals := DataRepository.get_rival_ludi()
	if rivals.size() != 7:
		return {"success": false, "reason": "canonical rival catalog does not contain 7 Ludi"}
	var results: Array[Dictionary] = []
	for index in range(rivals.size()):
		var rival := rivals[index] as Dictionary
		var wins := index
		results.append({"rival_id": str(rival.get("id", "")), "wins": wins, "points": wins * POINTS_PER_WIN})
	var registration := CampaignManager.register_gt1_rival_results(results)
	if str(registration.get("status", "")) != "registered":
		return {"success": false, "reason": str(registration.get("reason", registration))}
	return {"success": true}


func _validate_invariants(campaign_index: int, month: int) -> Array[String]:
	var errors: Array[String] = []
	if month < 1 or month > DEMO_FINAL_MONTH:
		errors.append("campaign %d has invalid month %d" % [campaign_index + 1, month])
	if GameState.food < 0:
		errors.append("month %d has negative food %d" % [month, GameState.food])
	if GameState.ore < 0:
		errors.append("month %d has negative ore %d" % [month, GameState.ore])
	if GameState.reputation < 0:
		errors.append("month %d has negative reputation %d" % [month, GameState.reputation])
	var summary := TournamentManager.get_gt1_summary()
	var points := int(summary.get("player_points", 0))
	var wins := int(summary.get("player_wins", 0))
	var bouts := int(summary.get("player_bouts", 0))
	if points != wins * POINTS_PER_WIN:
		errors.append("month %d GT1 points/wins invariant failed: %d != %d*%d" % [month, points, wins, POINTS_PER_WIN])
	if wins < 0 or bouts < wins or bouts > 9:
		errors.append("month %d GT1 win/bout counters are invalid: wins=%d bouts=%d" % [month, wins, bouts])
	return errors


func _result(errors: Array[String], months_advanced: int, events_resolved: int, gt1_bouts: int) -> Dictionary:
	return {
		"errors": errors.duplicate(),
		"months_advanced": months_advanced,
		"events_resolved": events_resolved,
		"gt1_bouts": gt1_bouts,
	}


func _get_int_argument(prefix: String, fallback: int, minimum: int, maximum: int) -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return clampi(int(argument.trim_prefix(prefix)), minimum, maximum)
	return fallback
