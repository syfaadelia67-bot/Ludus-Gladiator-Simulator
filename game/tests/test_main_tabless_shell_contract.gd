extends Node

func run() -> void:
    var scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")
    var controller := FileAccess.get_file_as_string("res://scripts/ui/main.gd")
    var bootstrap := FileAccess.get_file_as_string("res://scripts/ui/main_ui_bootstrap.gd")
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

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

    for forbidden_bootstrap_symbol in [
        "main_tabs",
        "TabContainer",
        'find_child("Tabs"',
        "_disconnect_legacy_combat_handlers",
        "_on_combat_finished",
        "_on_action_failed"
    ]:
        assert(not bootstrap.contains(forbidden_bootstrap_symbol))

    for forbidden_hub_symbol in [
        "TAB_PATH",
        "TabContainer",
        "_get_tabs",
        "_hide_legacy_tabs",
        'get_node_or_null("Margin/VBox/Tabs")'
    ]:
        assert(not hub.contains(forbidden_hub_symbol))

    assert(project.contains('AllTabsUIBootstrap="*res://scripts/ui/main_ui_bootstrap.gd"'))
    assert(not project.contains("all_tabs_ui_bootstrap.gd"))
    assert(bootstrap.contains("FincaHubController.prepare_scene()"))
    assert(hub.contains("return _ensure_screen_host(scene) != null"))
    assert(hub.contains("func _show_hosted_screen(system_id: String, host: Control) -> bool:"))

    var packed := load("res://scenes/Main.tscn") as PackedScene
    assert(packed != null)
    var instance := packed.instantiate()
    assert(instance != null)
    assert(instance.get_node_or_null("Margin/VBox/ScreenHost") != null)
    assert(instance.get_node_or_null("Margin/VBox/Tabs") == null)
    assert(instance.get_node_or_null("Margin/VBox/TopButtons/AdvanceDay") is Button)
    instance.free()

    print("Native tabless Main shell contract: OK")
