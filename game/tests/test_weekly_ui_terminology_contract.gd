extends Node

func _ready() -> void:
    var scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")
    var main_ui := FileAccess.get_file_as_string("res://scripts/ui/main.gd")
    var personal_ui := FileAccess.get_file_as_string("res://scripts/ui/personal_screen.gd")
    var combat := FileAccess.get_file_as_string("res://scripts/systems/combat_manager_weekly.gd")

    assert(scene.contains("Cerrar semana"))
    assert(scene.contains("Procesa trabajos, economía, eventos y recuperación"))
    assert(not scene.contains("Avanzar un día"))

    assert(main_ui.contains("func _on_advance_week()"))
    assert(main_ui.contains("GameState.advance_week()"))
    assert(not main_ui.contains("GameState.week_advanced.connect(_on_week_advanced)"))
    assert(not main_ui.contains("GameState.weekly_report.connect(_on_weekly_report)"))

    assert(personal_ui.contains("GameState.week_advanced.connect(_on_week_advanced)"))
    assert(personal_ui.contains("GameState.weekly_report.connect(_on_weekly_report)"))
    assert(personal_ui.contains("[b]Semana %d[/b]"))
    assert(personal_ui.contains("Mineral producido"))
    assert(not personal_ui.contains("[b]Día %d[/b]"))

    assert(not main_ui.contains("func _on_advance_day()"))
    assert(not main_ui.contains("[b]Día %d[/b]"))

    assert(combat.contains("El ludus ya disputó el combate de esta semana."))
    assert(combat.contains("Semana %d: %s"))
    assert(not combat.contains("El ludus ya combatió hoy."))
    assert(not combat.contains("Hoy no hay combates"))

    print("Weekly UI terminology contract: OK")
    get_tree().quit()
