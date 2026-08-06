extends Node

func run() -> void:
    var scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")
    var controller := FileAccess.get_file_as_string("res://scripts/ui/main.gd")
    var bootstrap := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(scene.contains('[node name="Main" type="Control"]'))
    assert(scene.contains('[node name="ScreenHost" type="Control" parent="Margin/VBox"]'))
    assert(not scene.contains('[node name="Tabs" type="TabContainer"'))
    assert(not scene.contains('parent="Margin/VBox/Tabs'))
    assert(not scene.contains('res://scripts/ui/equipment_panel.gd'))
    assert(not scene.contains('ui/arena_combat/combat_attack.png'))
    assert(not scene.contains('ui/arena_combat/combat_defense.png'))
    assert(not scene.contains('ui/arena_combat/combat_victory.png'))

    assert(controller.contains("GameState.resources_changed.connect(_refresh_resources)"))
    assert(controller.contains("RosterManager.roster_changed.connect(_refresh_resources)"))
    assert(controller.contains("GameState.advance_week()"))
    assert(not controller.contains("EstateManager."))
    assert(not controller.contains("MarketManager."))
    assert(not controller.contains("EquipmentManager."))
    assert(not controller.contains("CombatManager."))

    assert(bootstrap.contains('root.get_node_or_null("Margin/VBox/Tabs") as TabContainer'))
    assert(bootstrap.contains("if main_tabs != null:"))
    assert(hub.contains("func _get_tabs() -> TabContainer:"))
    assert(hub.contains("if tabs != null:"))

    var packed := load("res://scenes/Main.tscn") as PackedScene
    assert(packed != null)
    var instance := packed.instantiate()
    assert(instance != null)
    assert(instance.get_node_or_null("Margin/VBox/ScreenHost") != null)
    assert(instance.get_node_or_null("Margin/VBox/Tabs") == null)
    assert(instance.get_node_or_null("Margin/VBox/TopButtons/AdvanceDay") is Button)
    instance.free()

    print("Tabless Main shell contract: OK")
