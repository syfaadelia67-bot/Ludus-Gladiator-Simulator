extends Node

const CURRENT_SAVE_VERSION := 14
const PRIMARY_PATH := "user://ludus_save.json"
const BACKUP_PATH := "user://ludus_save.backup.json"

var rewrite_pending: bool = false

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
            push_warning("La campaña se cargó desde la copia de seguridad, pero no se pudo retirar el archivo principal dañado.")
            return

    rewrite_pending = true
    call_deferred("_rewrite_loaded_campaign")

func _rewrite_loaded_campaign() -> void:
    if not rewrite_pending:
        return
    rewrite_pending = false
    if not SaveManager.save_game():
        push_warning("La campaña se cargó, pero no pudo reescribirse con el formato de guardado actual.")
