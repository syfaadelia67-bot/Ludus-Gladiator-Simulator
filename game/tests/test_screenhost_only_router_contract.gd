extends Node

func run() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var bootstrap := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")

    assert(hub.contains("const SCREEN_SCENES"))
    assert(hub.contains('"personal": "res://scenes/PersonalScreen.tscn"'))
    assert(hub.contains('"equipamiento": "res://scenes/EquipmentScreen.tscn"'))
    assert(hub.contains('"forja": "res://scenes/ForgeScreen.tscn"'))
    assert(hub.contains("if not SCREEN_SCENES.has(normalized_id):"))
    assert(hub.contains("if not _show_hosted_screen(normalized_id, host):"))
    assert(hub.contains("func _show_hosted_screen(system_id: String, host: Control) -> bool:"))
    assert(hub.contains("func _ensure_screen_host(scene: Control) -> Control:"))
    assert(hub.contains("if vbox == null:"))
    assert(hub.contains("host.visible = true"))
    assert(hub.contains("host.mouse_filter = Control.MOUSE_FILTER_PASS"))

    for forbidden_hub_symbol in [
        "LEGACY_SYSTEM_TABS",
        "func _show_legacy_screen",
        "TAB_PATH",
        "TabContainer",
        "_get_tabs",
        "_hide_legacy_tabs",
        "tabs_visible",
        "tabs.mouse_filter"
    ]:
        assert(not hub.contains(forbidden_hub_symbol))

    assert(bootstrap.contains("FincaHubController.prepare_scene()"))
    assert(bootstrap.contains("_attach_unified_hud(root)"))
    assert(bootstrap.contains("_enforce_primary_hud_layout()"))

    for forbidden_bootstrap_symbol in [
        "main_tabs",
        "TabContainer",
        'find_child("Tabs"',
        "_disconnect_legacy_combat_handlers",
        "CombatManager.combat_finished",
        "CombatManager.combat_failed"
    ]:
        assert(not bootstrap.contains(forbidden_bootstrap_symbol))

    print("Native ScreenHost-only router contract: OK")
