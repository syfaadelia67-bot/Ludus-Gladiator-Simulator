extends Node

const CURRENT_SAVE_VERSION := 14
const SAVE_PATH := "user://ludus_save.json"
const BACKUP_PATH := "user://ludus_save.backup.json"

const STATUS_MISSING := "missing"
const STATUS_VALID := "valid"
const STATUS_RECOVERABLE_BACKUP := "recoverable_backup"
const STATUS_CORRUPT := "corrupt"
const STATUS_INCOMPATIBLE_NEWER := "incompatible_newer"
const STATUS_LEGACY_MIGRATABLE := "legacy_migratable"


func inspect() -> Dictionary:
	var primary := _inspect_path(SAVE_PATH)
	var backup := _inspect_path(BACKUP_PATH)
	var selected := primary
	var selected_path := SAVE_PATH

	if not bool(primary.get("loadable", false)) and bool(backup.get("loadable", false)):
		selected = backup
		selected_path = BACKUP_PATH

	var status := str(selected.get("status", STATUS_MISSING))
	if selected_path == BACKUP_PATH and bool(backup.get("loadable", false)):
		status = STATUS_RECOVERABLE_BACKUP
	elif (
		status == STATUS_MISSING
		and bool(primary.get("exists", false) or backup.get("exists", false))
	):
		status = STATUS_CORRUPT

	return {
		"status": status,
		"loadable": bool(selected.get("loadable", false)),
		"selected_path": selected_path if bool(selected.get("loadable", false)) else "",
		"primary": primary,
		"backup": backup,
		"metadata": selected.get("metadata", {}) if bool(selected.get("loadable", false)) else {},
		"message": _status_message(status),
	}


func _inspect_path(path: String) -> Dictionary:
	var result: Dictionary = {
		"path": path,
		"exists": FileAccess.file_exists(path),
		"loadable": false,
		"status": STATUS_MISSING,
		"metadata": {},
	}
	if not bool(result["exists"]):
		return result

	result["status"] = STATUS_CORRUPT
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return result

	var payload: Dictionary = parsed
	var version := int(payload.get("version", 0))
	result["metadata"] = _metadata(payload)
	var structural_error := _structural_error(payload)
	if not structural_error.is_empty():
		result["error"] = structural_error
	elif version > CURRENT_SAVE_VERSION:
		result["status"] = STATUS_INCOMPATIBLE_NEWER
	elif version < CURRENT_SAVE_VERSION:
		result["status"] = STATUS_LEGACY_MIGRATABLE
		result["loadable"] = true
	else:
		result["status"] = STATUS_VALID
		result["loadable"] = true
	return result


func _structural_error(payload: Dictionary) -> String:
	var error := ""
	var game_state: Variant = payload.get("game_state", null)
	var roster: Variant = payload.get("roster", null)
	var runtime_value: Variant = payload.get("combat_v1_runtime", null)
	if int(payload.get("version", 0)) <= 0:
		error = "missing_version"
	elif not game_state is Dictionary:
		error = "missing_game_state"
	elif not roster is Dictionary:
		error = "missing_roster"
	else:
		var state := game_state as Dictionary
		var fallback_day: Variant = state.get("day", 0)
		var fallback_week: Variant = state.get("week", fallback_day)
		var month := int(state.get("month", fallback_week))
		if month < 1:
			error = "invalid_month"
		elif not (roster as Dictionary).get("people", null) is Array:
			error = "invalid_roster"
		elif payload.has("combat_v1_runtime") and not runtime_value is Dictionary:
			error = "invalid_combat_v1_runtime"
	return error


func _metadata(payload: Dictionary) -> Dictionary:
	var game_state: Dictionary = payload.get("game_state", {})
	var owner_profile: Dictionary = payload.get("owner", {}).get("profile", {})
	var campaign: Dictionary = payload.get("campaign", {})
	var tournament: Dictionary = payload.get("tournaments", {})
	var month := maxi(
		1, int(game_state.get("month", game_state.get("week", game_state.get("day", 1))))
	)
	return {
		"version": int(payload.get("version", 0)),
		"month": month,
		# Compatibility metadata only. The canonical time axis is month.
		"week": month,
		"day": month,
		"owner_name": str(owner_profile.get("display_name", "")),
		"owner_title": str(owner_profile.get("title", "dominus")),
		"campaign_over": bool(campaign.get("campaign_over", false)),
		"victory": bool(campaign.get("victory", false)),
		"wins": maxi(0, int(campaign.get("wins", 0))),
		"losses": maxi(0, int(campaign.get("losses", 0))),
		"defeat_reason": str(campaign.get("defeat_reason", "")),
		"final_combat_resolved": bool(campaign.get("final_combat_resolved", false)),
		"gt1_player_points": clampi(int(tournament.get("gt1_player_points", 0)), 0, 27),
		"gt1_player_wins": clampi(int(tournament.get("gt1_player_wins", 0)), 0, 9),
		"gt1_player_bouts": clampi(int(tournament.get("gt1_player_bouts", 0)), 0, 9),
		"gt1_placement": clampi(int(tournament.get("gt1_placement", 0)), 0, 8),
		"gt1_medal": str(tournament.get("gt1_medal", "")),
		"gt1_standings_resolved": bool(tournament.get("gt1_standings_resolved", false)),
		"gt1_tiebreak_required": bool(tournament.get("gt1_tiebreak_required", false)),
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
		"combat_v1_runtime_present": payload.get("combat_v1_runtime", null) is Dictionary,
	}


func _status_message(status: String) -> String:
	match status:
		STATUS_VALID:
			return "Partida lista para continuar."
		STATUS_LEGACY_MIGRATABLE:
			return "Partida anterior compatible; se actualizará al cargarla."
		STATUS_RECOVERABLE_BACKUP:
			return "El guardado principal está dañado; hay una copia de seguridad recuperable."
		STATUS_INCOMPATIBLE_NEWER:
			return "La partida pertenece a una versión más nueva del juego."
		STATUS_CORRUPT:
			return "Se detectó un guardado incompleto o dañado."
		_:
			return "No hay una campaña guardada."
