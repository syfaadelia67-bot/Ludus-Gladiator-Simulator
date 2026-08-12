extends "res://scripts/systems/tournament_manager_weekly.gd"

const MonthlyNonGTActivityPolicyScript = preload(
	"res://scripts/systems/monthly_non_gt_activity_policy.gd"
)
const CANONICAL_COMPETITIONS := ["grand_tournament", "underworld", "official_minor"]

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
	if not _is_canonical_competition(str(event.get("competition", ""))):
		contract_failed.emit("La competición seleccionada no pertenece al calendario mensual canónico.")
		return false
	return super.accept_event(event_id, fighter_id)


func accept_event_team(event_id: String, fighter_ids: Array) -> bool:
	var event := _find_event(event_id)
	if event.is_empty():
		contract_failed.emit("El evento seleccionado ya no está disponible.")
		return false
	if not _is_canonical_competition(str(event.get("competition", ""))):
		contract_failed.emit("La competición seleccionada no pertenece al calendario mensual canónico.")
		return false
	if int(event.get("scheduled_month", GameState.get_month())) != GameState.get_month():
		contract_failed.emit("Solo podés inscribirte en competiciones del mes actual.")
		return false

	var expected_size := maxi(1, int(event.get("team_size", 1)))
	if expected_size <= 1 or fighter_ids.size() != expected_size:
		contract_failed.emit(
			"La competición requiere seleccionar exactamente %d gladiadores." % expected_size
		)
		return false

	var resolved_ids: Array[String] = []
	var fighter_names: Array[String] = []
	for raw_id in fighter_ids:
		var fighter_id := str(raw_id)
		if fighter_id.is_empty() or resolved_ids.has(fighter_id):
			contract_failed.emit("La selección de gladiadores debe ser completa y sin duplicados.")
			return false
		var fighter = RosterManager.get_person(fighter_id)
		if fighter == null or str(fighter.role) != "gladiator":
			contract_failed.emit("Seleccioná gladiadores válidos para la competición.")
			return false
		if not fighter.is_available_for_combat():
			contract_failed.emit("Uno de los gladiadores seleccionados no está disponible para competir.")
			return false
		if _has_active_contract_for_fighter(fighter_id):
			contract_failed.emit("Uno de los gladiadores ya tiene un combate programado este mes.")
			return false
		resolved_ids.append(fighter_id)
		fighter_names.append(str(fighter.display_name))

	if GameState.reputation < int(event.get("min_reputation", 0)):
		contract_failed.emit("La reputación del ludus es insuficiente.")
		return false
	var fee := int(event.get("entry_fee", 0))
	if not GameState.spend_denarii(fee):
		contract_failed.emit("No hay suficientes denarios para pagar la inscripción.")
		return false

	var contract := event.duplicate(true)
	contract["fighter_id"] = resolved_ids[0]
	contract["fighter_ids"] = resolved_ids.duplicate()
	contract["fighter_name"] = " + ".join(fighter_names)
	contract["fighter_names"] = fighter_names.duplicate()
	contract["accepted_month"] = GameState.get_month()
	contract["accepted_week"] = GameState.get_month()
	contract["accepted_day"] = GameState.get_month()
	contract["status"] = "programado"
	contract["bouts_resolved"] = 0
	active_contracts.append(contract)
	event["accepted"] = true
	contract_accepted.emit(contract.duplicate(true))
	calendar_changed.emit()
	return true


func get_active_contract_for_fighter(fighter_id: String) -> Dictionary:
	for contract in active_contracts:
		if _scheduled_month(contract) != GameState.get_month():
			continue
		if _contract_has_fighter(contract, fighter_id):
			return contract.duplicate(true)
	return {}


func get_active_contract_for_event(event_id: String) -> Dictionary:
	for contract in active_contracts:
		if str(contract.get("id", "")) != event_id:
			continue
		if _scheduled_month(contract) == GameState.get_month():
			return contract.duplicate(true)
	return {}


func register_combat_result(fighter_id: String, victory: bool) -> Dictionary:
	var matching := _find_due_contract_for_fighter(fighter_id)
	if matching.is_empty():
		return {}
	if not _is_canonical_competition(str(matching.get("competition", ""))):
		contract_failed.emit("El contrato activo no pertenece a una competición mensual canónica.")
		return {}
	return super.register_combat_result(fighter_id, victory)


func process_month() -> Array:
	return super.process_month()


func process_week() -> Array:
	return process_month()


func process_day() -> Array:
	return process_month()


func import_state(data: Dictionary) -> void:
	super.import_state(data)
	_quarantine_unsupported_contracts()
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
	var schedule: Array[Dictionary] = []
	if bool(policy.get("underworld_available", false)):
		schedule.append(_build_underworld_event(month))
	if bool(policy.get("gt1_month", false)):
		schedule.append(_build_gt1_event(month))
		return schedule
	if bool(policy.get("official_minor_available", false)):
		schedule.append(_build_minor_event(month, 1))
		if _has_second_official(month):
			schedule.append(_build_minor_event(month, 2))
	return schedule


func _is_canonical_competition(competition: String) -> bool:
	return CANONICAL_COMPETITIONS.has(competition)


func _has_active_contract_for_fighter(fighter_id: String) -> bool:
	for contract in active_contracts:
		if _scheduled_month(contract) > GameState.get_month():
			continue
		if _contract_has_fighter(contract, fighter_id):
			return true
	return false


func _contract_has_fighter(contract: Dictionary, fighter_id: String) -> bool:
	if str(contract.get("fighter_id", "")) == fighter_id:
		return true
	for raw_id in contract.get("fighter_ids", []) as Array:
		if str(raw_id) == fighter_id:
			return true
	return false


func _quarantine_unsupported_contracts() -> void:
	var removed_any := false
	for contract in active_contracts.duplicate():
		if _is_canonical_competition(str(contract.get("competition", ""))):
			continue
		active_contracts.erase(contract)
		removed_any = true
	if removed_any:
		calendar_changed.emit()
