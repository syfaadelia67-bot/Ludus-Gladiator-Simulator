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
    elif status == STATUS_MISSING and bool(primary.get("exists", false) or backup.get("exists", false)):
        status = STATUS_CORRUPT

    return {
        "status": status,
        "loadable": bool(selected.get("loadable", false)),
        "selected_path": selected_path if bool(selected.get("loadable", false)) else "",
        "primary": primary,
        "backup": backup,
        "metadata": selected.get("metadata", {}) if bool(selected.get("loadable", false)) else {},
        "message": _status_message(status)
    }

func _inspect_path(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"path":path, "exists":false, "loadable":false, "status":STATUS_MISSING, "metadata":{}}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"path":path, "exists":true, "loadable":false, "status":STATUS_CORRUPT, "metadata":{}}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
        return {"path":path, "exists":true, "loadable":false, "status":STATUS_CORRUPT, "metadata":{}}

    var payload: Dictionary = parsed
    var version := int(payload.get("version", 0))
    var structural_error := _structural_error(payload)
    if not structural_error.is_empty():
        return {"path":path, "exists":true, "loadable":false, "status":STATUS_CORRUPT, "error":structural_error, "metadata":_metadata(payload)}
    if version > CURRENT_SAVE_VERSION:
        return {"path":path, "exists":true, "loadable":false, "status":STATUS_INCOMPATIBLE_NEWER, "metadata":_metadata(payload)}
    if version < CURRENT_SAVE_VERSION:
        return {"path":path, "exists":true, "loadable":true, "status":STATUS_LEGACY_MIGRATABLE, "metadata":_metadata(payload)}
    return {"path":path, "exists":true, "loadable":true, "status":STATUS_VALID, "metadata":_metadata(payload)}

func _structural_error(payload: Dictionary) -> String:
    if int(payload.get("version", 0)) <= 0:
        return "missing_version"
    var game_state: Variant = payload.get("game_state", null)
    var roster: Variant = payload.get("roster", null)
    if not game_state is Dictionary:
        return "missing_game_state"
    if not roster is Dictionary:
        return "missing_roster"
    if int(game_state.get("week", game_state.get("day", 0))) < 1:
        return "invalid_week"
    if not roster.get("people", null) is Array:
        return "invalid_roster"
    return ""

func _metadata(payload: Dictionary) -> Dictionary:
    var game_state: Dictionary = payload.get("game_state", {})
    var owner_profile: Dictionary = payload.get("owner", {}).get("profile", {})
    var week := maxi(1, int(game_state.get("week", game_state.get("day", 1))))
    return {
        "version": int(payload.get("version", 0)),
        "week": week,
        "chapter": 1 if week <= 5 else (2 if week <= 11 else 3),
        "owner_name": str(owner_profile.get("display_name", "")),
        "owner_title": str(owner_profile.get("title", "dominus")),
        "saved_at_unix": int(payload.get("saved_at_unix", 0))
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
