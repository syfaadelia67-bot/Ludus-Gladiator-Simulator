extends Node

func _ready() -> void:
    var main_script := FileAccess.get_file_as_string("res://scripts/ui/main.gd")
    var scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")

    assert(scene.contains("text = \"Cerrar semana\""))
    assert(scene.contains("Registro semanal"))
    assert(scene.contains("Iniciar combate semanal"))
    assert(not scene.contains("Avanzar un día"))

    assert(main_script.contains("GameState.week_advanced.connect(_on_week_advanced)"))
    assert(main_script.contains("GameState.weekly_report.connect(_on_weekly_report)"))
    assert(main_script.contains("func _on_advance_week()"))
    assert(main_script.contains("GameState.advance_week()"))
    assert(main_script.contains("[b]Semana %d[/b]"))
    assert(main_script.contains("Comida consumida"))
    assert(not main_script.contains("GameState.day_advanced.connect"))
    assert(not main_script.contains("GameState.daily_report.connect"))
    assert(not main_script.contains("[b]Día %d[/b]"))

    print("Weekly main interface contract: OK")
    get_tree().quit()