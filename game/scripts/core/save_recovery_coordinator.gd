extends Node

signal recovery_completed(message: String)
signal recovery_failed(message: String)

const CURRENT_SAVE_VERSION := 14
const PRIMARY_PATH := "user://ludus_save.json"
const BACKUP_PATH := "user://ludus_save.backup.json"

var rewrite_pending: bool = false
var pending_recovered_from_backup: bool = false
var pending_requires_migration: bool = false

func _ready() -> void:
    SaveManager.load_completed.connect(_on_load_completed)

func _on_load_completed(loaded_path: String) -> void:
    var inspection := SaveCompatibilityInspector.inspect()
    var source_details: Dictionary = inspection.get("backup", {}) if loaded_path == BACKUP_PATH else inspection.get("primary", {})
    var source_version := int(source_details.get("metadata", {}).get("version", 0))
    var recovered_from_backup := loaded_path == BACKUP_PATH
    var requires_migration := source_version > 0 and source_version < CURRENT_SAVE_VERSION
    if not recovered_from_backup and not requires_migration:
        return

    if recovered_from_backup and FileAccess.file_exists(PRIMARY_PATH):
        var removal_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(PRIMARY_PATH))
        if removal_error != OK:
            var removal_message := "La campaña se cargó desde la copia de seguridad, pero no se pudo retirar el archivo principal dañado."
            push_warning(removal_message)
            recovery_failed.emit(removal_message)
            return

    pending_recovered_from_backup = recovered_from_backup
    pending_requires_migration = requires_migration
    rewrite_pending = true
    call_deferred("_rewrite_loaded_campaign")

func _rewrite_loaded_campaign() -> void:
    if not rewrite_pending:
        return
    rewrite_pending = false
    if not SaveManager.save_game():
        var failure_message := "La campaña se cargó, pero no pudo reescribirse con el formato de guardado actual."
        push_warning(failure_message)
        recovery_failed.emit(failure_message)
        _clear_pending_state()
        return

    recovery_completed.emit(_completion_message())
    _clear_pending_state()

func _completion_message() -> String:
    if pending_recovered_from_backup and pending_requires_migration:
        return "Campaña recuperada desde la copia de seguridad y actualizada al formato de guardado actual."
    if pending_recovered_from_backup:
        return "Campaña recuperada correctamente desde la copia de seguridad."
    return "Campaña anterior actualizada correctamente al formato de guardado actual."

func _clear_pending_state() -> void:
    pending_recovered_from_backup = false
    pending_requires_migration = false
