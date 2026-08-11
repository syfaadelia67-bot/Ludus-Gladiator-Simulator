extends Node

signal session_state_changed
signal recovery_applied(report: Dictionary)

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const GT1_MONTHS: Array[int] = [13, 16, 20]
const STORE_VERSION := 1

var _combat_contract = CombatContractScript.new()
var _gt1_session: Dictionary = {}
var _tiebreak_session: Dictionary = {}
var _last_import_report: Dictionary = {}


func set_gt1_session(session: Dictionary) -> bool:
	var status := str(session.get("status", ""))
	if status == "encounter_finished":
		clear_gt1_session()
		return true
	var errors := _validate_gt1_session(session, true)
	if not errors.is_empty():
		return false
	_gt1_session = session.duplicate(true)
	session_state_changed.emit()
	return true


func get_gt1_session(month: int = 0) -> Dictionary:
	var resolved_month := GameState.get_month() if month <= 0 else month
	if int(_gt1_session.get("month", 0)) != resolved_month:
		return {}
	return _gt1_session.duplicate(true)


func clear_gt1_session() -> void:
	if _gt1_session.is_empty():
		return
	_gt1_session.clear()
	session_state_changed.emit()


func set_tiebreak_session(session: Dictionary) -> bool:
	var status := str(session.get("status", ""))
	if status == "tiebreak_resolved":
		clear_tiebreak_session()
		return true
	var errors := _validate_tiebreak_session(session)
	if not errors.is_empty():
		return false
	_tiebreak_session = session.duplicate(true)
	session_state_changed.emit()
	return true


func get_tiebreak_session() -> Dictionary:
	return _tiebreak_session.duplicate(true)


func clear_tiebreak_session() -> void:
	if _tiebreak_session.is_empty():
		return
	_tiebreak_session.clear()
	session_state_changed.emit()


func clear_all() -> void:
	var changed := not _gt1_session.is_empty() or not _tiebreak_session.is_empty()
	_gt1_session.clear()
	_tiebreak_session.clear()
	_last_import_report.clear()
	if changed:
		session_state_changed.emit()


func export_state() -> Dictionary:
	return {
		"store_version": STORE_VERSION,
		"gt1_session": _gt1_session.duplicate(true),
		"tiebreak_session": _tiebreak_session.duplicate(true),
	}


func import_state(data: Dictionary) -> bool:
	_gt1_session.clear()
	_tiebreak_session.clear()
	_last_import_report = {
		"status": "loaded",
		"gt1_session_restored": false,
		"tiebreak_session_restored": false,
		"legacy_partial_gt1_recovered": false,
		"errors": [],
	}

	var gt1_value: Variant = data.get("gt1_session", {})
	if gt1_value is Dictionary and not gt1_value.is_empty():
		var gt1_session := gt1_value as Dictionary
		var gt1_errors := _validate_gt1_session(gt1_session, true)
		if gt1_errors.is_empty():
			_gt1_session = gt1_session.duplicate(true)
			_last_import_report["gt1_session_restored"] = true
		else:
			_last_import_report["errors"] = gt1_errors.duplicate()
	elif not _recover_legacy_partial_gt1_if_needed():
		_last_import_report["status"] = "rejected"
		session_state_changed.emit()
		return false

	if _gt1_session.is_empty() and _has_partial_current_gt1_progress():
		if not _recover_legacy_partial_gt1_if_needed():
			_last_import_report["status"] = "rejected"
			session_state_changed.emit()
			return false

	var tiebreak_value: Variant = data.get("tiebreak_session", {})
	if tiebreak_value is Dictionary and not tiebreak_value.is_empty():
		var tiebreak_session := tiebreak_value as Dictionary
		var tiebreak_errors := _validate_tiebreak_session(tiebreak_session)
		if tiebreak_errors.is_empty():
			_tiebreak_session = tiebreak_session.duplicate(true)
			_last_import_report["tiebreak_session_restored"] = true
		else:
			var errors := _last_import_report.get("errors", []) as Array
			errors.append_array(tiebreak_errors)
			_last_import_report["errors"] = errors

	if not (_last_import_report.get("errors", []) as Array).is_empty():
		_last_import_report["status"] = "recovered"
	session_state_changed.emit()
	return true


func get_last_import_report() -> Dictionary:
	return _last_import_report.duplicate(true)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"save_version": 14,
		"save_section": "combat_v1_runtime",
		"save_shape": "additive_dictionary",
		"gt1_running_session_persisted": true,
		"gt1_consecutive_carryover_persisted": true,
		"championship_tiebreak_session_persisted": true,
		"championship_rematch_state_persisted": true,
		"legacy_partial_gt1_without_session": "rollback_incomplete_encounter_from_history",
		"legacy_tiebreak_without_session": "restart_tiebreak_from_beginning",
		"invent_missing_combat_state_allowed": false,
		"save_version_change_required": false,
	}


func _validate_gt1_session(
	session: Dictionary, require_tournament_consistency: bool
) -> Array[String]:
	var errors: Array[String] = []
	if str(session.get("status", "")) != "combat_running":
		errors.append("Persisted GT I session must be combat_running")
	var month := int(session.get("month", 0))
	if not GT1_MONTHS.has(month):
		errors.append("Persisted GT I session must belong to month XIII, XVI or XX")
	var completed_bouts := int(session.get("completed_bouts", -1))
	if completed_bouts < 0 or completed_bouts >= 3:
		errors.append("Persisted GT I running session must have 0 to 2 completed bouts")
	if int(session.get("bout_index", -1)) != completed_bouts:
		errors.append("Persisted GT I bout index must equal completed bout count")
	if str(session.get("player_team_id", "")).is_empty():
		errors.append("Persisted GT I session requires player_team_id")
	var templates_value: Variant = session.get("bout_templates", null)
	if not templates_value is Array or (templates_value as Array).size() != 3:
		errors.append("Persisted GT I session requires exactly three bout templates")
	var active_loop_value: Variant = session.get("active_loop", null)
	if not active_loop_value is Dictionary:
		errors.append("Persisted GT I session requires an active loop")
	else:
		var active_loop := active_loop_value as Dictionary
		if str(active_loop.get("status", "")) != "running":
			errors.append("Persisted GT I active loop must be running")
		var state_value: Variant = active_loop.get("state", null)
		if not state_value is Dictionary:
			errors.append("Persisted GT I active loop requires CombatState")
		else:
			errors.append_array(_combat_contract.validate_state(state_value as Dictionary))
	if require_tournament_consistency and errors.is_empty():
		var progress := (
			TournamentManager.get_gt1_summary().get("encounter_progress", {}) as Dictionary
		)
		if int(progress.get(str(month), -1)) != completed_bouts:
			errors.append("Persisted GT I session conflicts with TournamentManager progress")
	return errors


func _validate_tiebreak_session(session: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var status := str(session.get("status", ""))
	if status not in ["tiebreak_combat_running", "rematch_required"]:
		errors.append("Persisted championship tiebreak has unsupported status")
	if not bool(TournamentManager.get_gt1_summary().get("tiebreak_required", false)):
		errors.append("Persisted championship tiebreak requires unresolved GT I standings")
	if status == "tiebreak_combat_running":
		var active_loop_value: Variant = session.get("active_loop", null)
		if not active_loop_value is Dictionary:
			errors.append("Running championship tiebreak requires active loop")
		else:
			var active_loop := active_loop_value as Dictionary
			if str(active_loop.get("status", "")) != "running":
				errors.append("Running championship tiebreak loop must be running")
			var state_value: Variant = active_loop.get("state", null)
			if not state_value is Dictionary:
				errors.append("Running championship tiebreak requires CombatState")
			else:
				errors.append_array(_combat_contract.validate_state(state_value as Dictionary))
	elif (
		str((session.get("standings_resolution", {}) as Dictionary).get("status", ""))
		!= "rematch_required"
	):
		errors.append("Championship rematch state requires rematch_required resolution")
	return errors


func _has_partial_current_gt1_progress() -> bool:
	var month := GameState.get_month()
	if not GT1_MONTHS.has(month):
		return false
	var progress := TournamentManager.get_gt1_summary().get("encounter_progress", {}) as Dictionary
	var completed := int(progress.get(str(month), 0))
	return completed > 0 and completed < 3


func _recover_legacy_partial_gt1_if_needed() -> bool:
	if not _has_partial_current_gt1_progress():
		return true
	var recovery := TournamentManager.rollback_incomplete_gt1_encounter(GameState.get_month())
	if str(recovery.get("status", "")) != "recovered":
		var errors := _last_import_report.get("errors", []) as Array
		errors.append(
			str(recovery.get("reason", "Unable to recover incomplete legacy GT I encounter"))
		)
		_last_import_report["errors"] = errors
		return false
	_last_import_report["status"] = "recovered"
	_last_import_report["legacy_partial_gt1_recovered"] = true
	_last_import_report["gt1_recovery"] = recovery.duplicate(true)
	recovery_applied.emit(_last_import_report.duplicate(true))
	return true
