extends Node

func _ready() -> void:
    var hud_scene := FileAccess.get_file_as_string("res://scenes/UnifiedHudShell.tscn")
    var closure := FileAccess.get_file_as_string("res://scripts/ui/weekly_closure_presenter.gd")
    var personal_ui := FileAccess.get_file_as_string("res://scripts/ui/personal_screen.gd")
    var combat := FileAccess.get_file_as_string("res://scripts/systems/combat_manager_weekly.gd")
    var main_scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")

    assert(hud_scene.contains("Cerrar semana"))
    assert(hud_scene.contains("Procesar trabajos, economía, recuperación y eventos de la semana."))
    assert(not hud_scene.contains("Avanzar un día"))
    assert(not main_scene.contains("Cerrar semana"))
    assert(not main_scene.contains("Avanzar un día"))

    assert(closure.contains('const BUTTON_PATH := "UnifiedHudShell/TopHUD/Margin/Row/AdvanceWeek"'))
    assert(closure.contains("GameState.advance_week()"))
    assert(not closure.contains("func _on_advance_day()"))
    assert(not closure.contains("[b]Día %d[/b]"))

    assert(personal_ui.contains("GameState.week_advanced.connect(_on_week_advanced)"))
    assert(personal_ui.contains("GameState.weekly_report.connect(_on_weekly_report)"))
    assert(personal_ui.contains("[b]Semana %d[/b]"))
    assert(personal_ui.contains("Mineral producido"))
    assert(not personal_ui.contains("[b]Día %d[/b]"))

    assert(combat.contains("El ludus ya disputó el combate de esta semana."))
    assert(combat.contains("Semana %d: %s"))
    assert(not combat.contains("El ludus ya combatió hoy."))
    assert(not combat.contains("Hoy no hay combates"))

    print("Weekly UI terminology contract: OK")
    get_tree().quit()
