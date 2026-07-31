extends SceneTree

const INSPECTOR_PATH := "res://scripts/core/save_compatibility_inspector.gd"
const PROJECT_PATH := "res://project.godot"

func _init() -> void:
    var inspector_source := FileAccess.get_file_as_string(INSPECTOR_PATH)
    var project_source := FileAccess.get_file_as_string(PROJECT_PATH)
    var required_statuses := [
        "STATUS_MISSING",
        "STATUS_VALID",
        "STATUS_RECOVERABLE_BACKUP",
        "STATUS_CORRUPT",
        "STATUS_INCOMPATIBLE_NEWER",
        "STATUS_LEGACY_MIGRATABLE"
    ]

    assert(not inspector_source.is_empty(), "Debe existir el inspector de compatibilidad de guardados.")
    for status_name in required_statuses:
        assert(inspector_source.contains(status_name), "Falta el estado de guardado %s." % status_name)
    assert(inspector_source.contains("func inspect() -> Dictionary"), "El inspector debe exponer un diagnóstico completo.")
    assert(inspector_source.contains("BACKUP_PATH"), "El diagnóstico debe contemplar la copia de seguridad.")
    assert(inspector_source.contains("version > CURRENT_SAVE_VERSION"), "Debe detectar partidas creadas por versiones futuras.")
    assert(inspector_source.contains("version < CURRENT_SAVE_VERSION"), "Debe identificar partidas antiguas migrables.")
    assert(inspector_source.contains("_structural_error"), "Debe diferenciar estructura dañada de incompatibilidad de versión.")
    assert(project_source.contains("SaveCompatibilityInspector=\"*res://scripts/core/save_compatibility_inspector.gd\""), "El inspector debe estar registrado como autoload.")
    print("Save compatibility contract: OK")
    quit(0)
