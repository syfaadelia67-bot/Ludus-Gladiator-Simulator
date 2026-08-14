extends Node


func _ready() -> void:
	var hud_scene := FileAccess.get_file_as_string("res://scenes/UnifiedHudShell.tscn")
	var hud_script := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")
	var closure := FileAccess.get_file_as_string("res://scripts/ui/weekly_closure_presenter.gd")
	var personal_ui := FileAccess.get_file_as_string("res://scripts/ui/personal_screen.gd")
	var personal_scene := FileAccess.get_file_as_string("res://scenes/PersonalScreen.tscn")
	var main_scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")

	assert(hud_scene.contains("Cerrar mes"))
	assert(hud_scene.contains("Procesar trabajos, economía, recuperación y eventos del mes."))
	assert(hud_scene.contains('text = "MES 1"'))
	assert(not hud_scene.contains("Cerrar semana"))
	assert(not hud_scene.contains("Avanzar un día"))
	assert(not main_scene.contains("Cerrar semana"))
	assert(not main_scene.contains("Avanzar un día"))

	assert(closure.contains('const BUTTON_PATH := "UnifiedHudShell/TopHUD/Margin/Row/AdvanceWeek"'))
	assert(closure.contains("GameState.advance_month()"))
	assert(not closure.contains("GameState.advance_week()"))
	assert(not closure.contains("func _on_advance_day()"))
	assert(not closure.contains("[b]Día %d[/b]"))

	assert(personal_scene.contains("Registro mensual"))
	assert(personal_ui.contains("GameState.month_advanced.connect(_on_month_advanced)"))
	assert(personal_ui.contains("GameState.monthly_report.connect(_on_monthly_report)"))
	assert(personal_ui.contains('"\\n\\n[b]Mes %d[/b]"'))
	assert(personal_ui.contains("Mineral producido"))
	assert(not personal_ui.contains("GameState.week_advanced.connect"))
	assert(not personal_ui.contains("GameState.weekly_report.connect"))
	assert(not personal_ui.contains("[b]Semana %d[/b]"))
	assert(not personal_ui.contains("[b]Día %d[/b]"))

	assert(hud_script.contains("GameState.month_advanced.connect"))
	assert(hud_script.contains("GameState.advance_month()"))
	assert(hud_script.contains("TournamentManager.get_gt1_encounter(month)"))
	assert(not hud_script.contains("GameState.week_advanced.connect"))
	assert(not hud_script.contains("GameState.DAYS_PER_WEEK"))
	assert(not hud_script.contains("CombatManager.get_current_event_details()"))

	print("Monthly UI terminology contract: OK")
	get_tree().quit()
