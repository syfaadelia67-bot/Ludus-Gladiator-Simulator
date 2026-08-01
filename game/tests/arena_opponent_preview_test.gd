extends Node

func run() -> void:
    var combat_source := FileAccess.get_file_as_string("res://scripts/systems/combat_manager_weekly.gd")
    var presenter_source := FileAccess.get_file_as_string("res://scripts/ui/arena_opponent_preview_presenter.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    _assert(combat_source.contains("func get_current_opponent_preview"), "CombatManager debe exponer la vista previa semanal.")
    _assert(combat_source.contains("RivalUniqueGladiatorController.get_opponent_for_week"), "La vista previa debe usar la misma selección determinista que el combate.")
    _assert(combat_source.contains("Bestia no revelada"), "Las cacerías deben ocultar la bestia antes del combate.")
    _assert(combat_source.contains("GladiatorRivalryController.get_rivalry"), "La vista previa debe consultar el historial cara a cara.")
    _assert(presenter_source.contains("OpponentPreview"), "Arena debe montar un panel de próximo oponente.")
    _assert(presenter_source.contains("Marcador personal"), "La UI debe mostrar el marcador de rivalidad.")
    _assert(presenter_source.contains("Récord rival"), "La UI debe mostrar el récord del oponente.")
    _assert(presenter_source.contains("Vida estimada"), "La UI debe distinguir estadísticas estimadas.")
    _assert(project_source.contains("ArenaOpponentPreviewPresenter=\"*res://scripts/ui/arena_opponent_preview_presenter.gd\""), "El presentador debe estar registrado como autoload.")
    print("arena_opponent_preview_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("arena_opponent_preview_test: %s" % message)
        assert(condition, message)
