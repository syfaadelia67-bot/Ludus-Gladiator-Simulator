extends Node


func _ready() -> void:
	var hud_script := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")
	var hud_scene := FileAccess.get_file_as_string("res://scenes/UnifiedHudShell.tscn")
	var closure := FileAccess.get_file_as_string("res://scripts/ui/weekly_closure_presenter.gd")
	var personal_script := FileAccess.get_file_as_string("res://scripts/ui/personal_screen.gd")
	var personal_scene := FileAccess.get_file_as_string("res://scenes/PersonalScreen.tscn")
	var arena_scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
	var main_scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")

	assert(hud_scene.contains('text = "Cerrar mes"'))
	assert(hud_scene.contains('text = "MES 1"'))
	assert(hud_scene.contains('[node name="AdvanceWeek" type="Button" parent="TopHUD/Margin/Row"]'))
	assert(main_scene.contains('[node name="ScreenHost" type="Control" parent="Margin/VBox"]'))
	assert(not main_scene.contains('[node name="Tabs" type="TabContainer"'))
	assert(not main_scene.contains("AdvanceDay"))
	assert(not main_scene.contains("Avanzar un día"))
	assert(personal_scene.contains("Registro mensual"))
	assert(arena_scene.contains('name="StartCombat"') or arena_scene.contains('name = "StartCombat"'))

	assert(hud_script.contains("@onready var advance_week_button"))
	assert(hud_script.contains("GameState.month_advanced.connect"))
	assert(hud_script.contains("GameState.advance_month()"))
	assert(hud_script.contains('week_summary.text = "MES %d"'))
	assert(not hud_script.contains("GameState.week_advanced.connect"))
	assert(not hud_script.contains("GameState.DAYS_PER_WEEK"))
	assert(
		closure.contains('const BUTTON_PATH := "UnifiedHudShell/TopHUD/Margin/Row/AdvanceWeek"')
	)
	assert(closure.contains("advance_button.pressed.connect(open_summary)"))
	assert(closure.contains("GameState.advance_month()"))

	assert(personal_script.contains("GameState.month_advanced.connect(_on_month_advanced)"))
	assert(personal_script.contains("GameState.monthly_report.connect(_on_monthly_report)"))
	assert(personal_script.contains('"\\n\\n[b]Mes %d[/b]"'))
	assert(personal_script.contains("Seguridad generada"))
	assert(personal_script.contains("Entrenamiento total"))
	assert(not personal_script.contains("GameState.week_advanced.connect"))
	assert(not personal_script.contains("GameState.weekly_report.connect"))

	assert(not hud_script.contains("GameState.day_advanced.connect"))
	assert(not hud_script.contains("GameState.daily_report.connect"))
	assert(not hud_script.contains("[b]Día %d[/b]"))
	assert(not personal_script.contains("[b]Día %d[/b]"))

	print("Unified HUD monthly interface contract: OK")
	get_tree().quit()
