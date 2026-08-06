extends Node

func run() -> void:
    var scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")
    var hud := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")
    var closure := FileAccess.get_file_as_string("res://scripts/ui/weekly_closure_presenter.gd")
    var menu := FileAccess.get_file_as_string("res://scripts/ui/main_menu_return_controller.gd")

    assert(not FileAccess.file_exists("res://scripts/ui/main.gd"))
    assert(not scene.contains("res://scripts/ui/main.gd"))
    assert(not scene.contains("TopButtons"))
    assert(not scene.contains("RefreshMarket"))
    assert(not scene.contains("AdvanceDay"))
    assert(not scene.contains("Capacity"))

    assert(hud.contains("GameState.resources_changed.connect(_refresh_all)"))
    assert(hud.contains("RosterManager.roster_changed.connect(_refresh_all)"))
    assert(hud.contains("func _refresh_top_hud()"))
    assert(hud.contains("RosterManager.get_capacity_summary()"))
    assert(hud.contains("@onready var advance_week_button"))

    assert(closure.contains('const BUTTON_PATH := "UnifiedHudShell/TopHUD/Margin/Row/AdvanceWeek"'))
    assert(closure.contains("advance_button.pressed.connect(open_summary)"))
    assert(closure.contains("GameState.advance_week()"))

    assert(menu.contains('const HUD_ROW_PATH := "UnifiedHudShell/TopHUD/Margin/Row"'))
    assert(menu.contains("Guardar y menú"))
    assert(menu.contains("SaveManager.save_game()"))

    print("Main controller removal and hosted ownership contract: OK")
