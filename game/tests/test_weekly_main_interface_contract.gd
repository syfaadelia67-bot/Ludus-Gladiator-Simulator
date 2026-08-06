extends Node

func _ready() -> void:
    var main_script := FileAccess.get_file_as_string("res://scripts/ui/main.gd")
    var personal_script := FileAccess.get_file_as_string("res://scripts/ui/personal_screen.gd")
    var personal_scene := FileAccess.get_file_as_string("res://scenes/PersonalScreen.tscn")
    var arena_scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
    var scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")

    assert(scene.contains("text = \"Cerrar semana\""))
    assert(scene.contains('[node name="ScreenHost" type="Control" parent="Margin/VBox"]'))
    assert(not scene.contains('[node name="Tabs" type="TabContainer"'))
    assert(not scene.contains("Avanzar un día"))
    assert(personal_scene.contains("Registro semanal"))
    assert(arena_scene.contains('name="StartCombat"') or arena_scene.contains('name = "StartCombat"'))

    assert(main_script.contains("func _on_advance_week()"))
    assert(main_script.contains("GameState.advance_week()"))
    assert(not main_script.contains("GameState.week_advanced.connect(_on_week_advanced)"))
    assert(not main_script.contains("GameState.weekly_report.connect(_on_weekly_report)"))

    assert(personal_script.contains("GameState.week_advanced.connect(_on_week_advanced)"))
    assert(personal_script.contains("GameState.weekly_report.connect(_on_weekly_report)"))
    assert(personal_script.contains("[b]Semana %d[/b]"))
    assert(personal_script.contains("Seguridad generada"))
    assert(personal_script.contains("Entrenamiento total"))

    assert(not main_script.contains("GameState.day_advanced.connect"))
    assert(not main_script.contains("GameState.daily_report.connect"))
    assert(not main_script.contains("[b]Día %d[/b]"))
    assert(not personal_script.contains("[b]Día %d[/b]"))

    print("Weekly main interface contract: OK")
    get_tree().quit()
