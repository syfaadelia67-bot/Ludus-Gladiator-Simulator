extends Node

func _ready() -> void:
    var source := FileAccess.get_file_as_string("res://scripts/core/save_compatibility_inspector.gd")

    assert(source.contains("CURRENT_SAVE_VERSION := 14"))
    assert(source.contains("STATUS_VALID"))
    assert(source.contains("STATUS_RECOVERABLE_BACKUP"))
    assert(source.contains("STATUS_CORRUPT"))
    assert(source.contains("STATUS_INCOMPATIBLE_NEWER"))
    assert(source.contains("STATUS_LEGACY_MIGRATABLE"))
    assert(source.contains("func inspect()"))
    assert(source.contains("func _structural_error"))
    assert(source.contains("missing_game_state"))
    assert(source.contains("missing_roster"))
    assert(source.contains("invalid_week"))
    assert(source.contains("invalid_roster"))
    assert(source.contains("selected_path == BACKUP_PATH"))
    assert(source.contains("La partida pertenece a una versión más nueva del juego."))
    assert(source.contains("El guardado principal está dañado; hay una copia de seguridad recuperable."))

    print("Save compatibility inspector contract: OK")
    get_tree().quit()
