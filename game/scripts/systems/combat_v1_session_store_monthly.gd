extends "res://scripts/systems/combat_v1_session_store.gd"

const NON_GT_COMPETITIONS := ["underworld", "official_minor"]

var _non_gt_session: Dictionary = {}


func set_non_gt_session(session: Dictionary) -> bool:
	if str(session.get("status", "")) == "encounter_finished":
		clear_non_gt_session()
		return true
	var errors := _validate_non_gt_session(session)
	if not errors.is_empty():
		return false
	_non_gt_session = session.duplicate(true)
	session_state_changed.emit()
	return true


func get_non_gt_session(month: int = 0) -> Dictionary:
	var resolved_month := GameState.get_month() if month <= 0 else month
	if int(_non_gt_session.get("month", 0)) != resolved_month:
		return {}
	return _non_gt_session.duplicate(true)


func clear_non_gt_session() -> void:
	if _non_gt_session.is_empty():
		return
	_non_gt_session.clear()
	session_state_changed.emit()


func clear_all() -> void:
	var had_non_gt := not _non_gt_session.is_empty()
	super.clear_all()
	_non_gt_session.clear()
	if had_non_gt:
		session_state_changed.emit()


func export_state() -> Dictionary:
	var data := super.export_state()
	data["non_gt_session"] = _non_gt_session.duplicate(true)
	return data


func import_state(data: Dictionary) -> bool:
	_non_gt_session.clear()
	if not super.import_state(data):
		return false
	_last_import_report["non_gt_session_restored"] = false
	var value: Variant = data.get("non_gt_session", {})
	if value is Dictionary and not value.is_empty():
		var session := value as Dictionary
		var errors := _validate_non_gt_session(session)
		if errors.is_empty():
			_non_gt_session = session.duplicate(true)
			_last_import_report["non_gt_session_restored"] = true
		else:
			var report_errors := _last_import_report.get("errors", []) as Array
			report_errors.append_array(errors)
			_last_import_report["errors"] = report_errors
			_last_import_report["status"] = "recovered"
	session_state_changed.emit()
	return true


func get_contract() -> Dictionary:
	var contract := super.get_contract()
	contract["monthly_non_gt_running_session_persisted"] = true
	contract["monthly_non_gt_competitions"] = NON_GT_COMPETITIONS.duplicate()
	contract["monthly_non_gt_finished_session_persisted"] = false
	contract["save_version"] = 14
	contract["save_shape"] = "additive_dictionary"
	contract["save_version_change_required"] = false
	return contract


func _validate_non_gt_session(session: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(session.get("status", "")) != "combat_running":
		errors.append("Persisted monthly Arena session must be combat_running")
	if str(session.get("session_kind", "")) != "monthly_non_gt":
		errors.append("Persisted monthly Arena session must be monthly_non_gt")
	if not NON_GT_COMPETITIONS.has(str(session.get("competition", ""))):
		errors.append("Persisted monthly Arena competition is not canonical")
	if int(session.get("month", 0)) <= 0:
		errors.append("Persisted monthly Arena session requires a positive month")
	if str(session.get("event_id", "")).is_empty():
		errors.append("Persisted monthly Arena session requires event_id")
	if str(session.get("fighter_id", "")).is_empty():
		errors.append("Persisted monthly Arena session requires fighter_id")
	if str(session.get("player_team_id", "")).is_empty():
		errors.append("Persisted monthly Arena session requires player_team_id")
	var active_loop_value: Variant = session.get("active_loop", null)
	if not active_loop_value is Dictionary:
		errors.append("Persisted monthly Arena session requires an active loop")
	else:
		var active_loop := active_loop_value as Dictionary
		if str(active_loop.get("status", "")) != "running":
			errors.append("Persisted monthly Arena active loop must be running")
		var state_value: Variant = active_loop.get("state", null)
		if not state_value is Dictionary:
			errors.append("Persisted monthly Arena active loop requires CombatState")
		else:
			errors.append_array(_combat_contract.validate_state(state_value as Dictionary))
	return errors
