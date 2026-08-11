extends "res://scripts/systems/tournament_manager_weekly.gd"

const MonthlyNonGTActivityPolicyScript = preload(
	"res://scripts/systems/monthly_non_gt_activity_policy.gd"
)

var _non_gt_activity_policy = MonthlyNonGTActivityPolicyScript.new()


func _ready() -> void:
	prepare_month(GameState.get_month(), true)


func prepare_month(month: int, force: bool = false) -> void:
	var resolved_month := maxi(1, month)
	if not force and _calendar_matches_month(resolved_month):
		return
	available_events.clear()
	for event in _build_canonical_month_schedule(resolved_month):
		available_events.append(event)
	calendar_changed.emit()


func get_month_schedule(month: int = 0) -> Array:
	var resolved_month := GameState.get_month() if month <= 0 else maxi(1, month)
	return _build_canonical_month_schedule(resolved_month).duplicate(true)


func accept_event(event_id: String, fighter_id: String) -> bool:
	var event := _find_event(event_id)
	if event.is_empty():
		contract_failed.emit("El evento seleccionado ya no está disponible.")
		return false
	if str(event.get("competition", "")) != "grand_tournament":
		var reason := (
			"Las competiciones fuera del Gran Torneo de Roma están en pausa "
			+ "hasta congelar sus reglas mensuales."
		)
		contract_failed.emit(reason)
		return false
	return super.accept_event(event_id, fighter_id)


func register_combat_result(fighter_id: String, victory: bool) -> Dictionary:
	var matching := _find_due_contract_for_fighter(fighter_id)
	if matching.is_empty():
		return {}
	if str(matching.get("competition", "")) != "grand_tournament":
		contract_failed.emit(
			"Un contrato legacy fuera del GT I no puede registrar un resultado canónico de campaña."
		)
		return {}
	return super.register_combat_result(fighter_id, victory)


func process_month() -> Array:
	_quarantine_legacy_non_gt_contracts()
	var results: Array = []
	var current_month := GameState.get_month()
	if is_grand_tournament_month(current_month):
		_close_gt1_encounter(current_month)
	monthly_tournaments_processed.emit(results.duplicate(true))
	weekly_tournaments_processed.emit(results.duplicate(true))
	return results


func process_week() -> Array:
	return process_month()


func process_day() -> Array:
	return process_month()


func import_state(data: Dictionary) -> void:
	super.import_state(data)
	_quarantine_legacy_non_gt_contracts()
	prepare_month(GameState.get_month(), true)


func rollback_incomplete_gt1_encounter(month: int) -> Dictionary:
	if not is_grand_tournament_month(month):
		return {"status": "rejected", "reason": "Month is not a GT I encounter."}
	var key := str(month)
	var completed := int(gt1_encounter_progress.get(key, 0))
	if completed <= 0 or completed >= GT1_BOUTS_PER_ENCOUNTER:
		return {"status": "not_required", "month": month, "completed_bouts": completed}

	var matching_results: Array[Dictionary] = []
	for raw_entry in history:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		if (
			str(entry.get("competition", "")) == "grand_tournament"
			and int(entry.get("month", 0)) == month
		):
			matching_results.append(entry)
	if matching_results.size() != completed:
		return {
			"status": "rejected",
			"reason": "Saved GT I progress does not match its combat history.",
			"month": month,
			"completed_bouts": completed,
			"history_bouts": matching_results.size(),
		}

	var removed_wins := 0
	var removed_points := 0
	for entry in matching_results:
		if bool(entry.get("victory", false)):
			removed_wins += 1
		removed_points += int(entry.get("points_gained", 0))
		history.erase(entry)

	gt1_encounter_progress[key] = 0
	gt1_player_bouts = maxi(0, gt1_player_bouts - completed)
	gt1_player_wins = maxi(0, gt1_player_wins - removed_wins)
	gt1_player_points = maxi(0, gt1_player_points - removed_points)
	gt1_standings.clear()
	gt1_placement = 0
	gt1_medal = ""
	gt1_standings_resolved = false
	gt1_tiebreak_required = false
	grand_tournament_changed.emit(get_gt1_summary())
	calendar_changed.emit()
	return {
		"status": "recovered",
		"month": month,
		"rolled_back_bouts": completed,
		"rolled_back_wins": removed_wins,
		"rolled_back_points": removed_points,
		"recovery_policy": "restart_incomplete_encounter_without_inventing_combat_state",
	}


func get_non_gt_activity_contract() -> Dictionary:
	return _non_gt_activity_policy.get_contract()


func _build_canonical_month_schedule(month: int) -> Array[Dictionary]:
	var policy := _non_gt_activity_policy.evaluate_month(month)
	if not bool(policy.get("gt1_month", false)):
		return []
	return [_build_gt1_event(month)]


func _quarantine_legacy_non_gt_contracts() -> void:
	var removed_any := false
	for contract in active_contracts.duplicate():
		if not _non_gt_activity_policy.is_legacy_non_gt_competition(
			str(contract.get("competition", ""))
		):
			continue
		active_contracts.erase(contract)
		removed_any = true
	if removed_any:
		calendar_changed.emit()
