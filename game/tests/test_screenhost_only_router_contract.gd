extends Node

func run() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var bootstrap := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")

    assert(hub.contains("const SCREEN_SCENES"))
    assert(hub.contains('"personal": "res://scenes/PersonalScreen.tscn"'))
    assert(hub.contains('"equipamiento": "res://scenes/EquipmentScreen.tscn"'))
    assert(hub.contains('"forja": "res://scenes/ForgeScreen.tscn"'))
    assert(not hub.contains("LEGACY_SYSTEM_TABS"))
    assert(not hub.contains("func _show_legacy_screen"))
    assert(hub.contains("if not SCREEN_SCENES.has(normalized_id):"))
    assert(hub.contains("if not _show_hosted_screen(normalized_id, host):"))
    assert(hub.contains("func _hide_legacy_tabs()"))
    assert(hub.contains("if tabs == null:"))
    assert(hub.contains("if vbox == null:"))
    assert(not hub.contains("if scene == null or tabs == null:"))
    assert(not hub.contains("if vbox == null or tabs == null:"))

    assert(bootstrap.contains('main_tabs = root.find_child("Tabs", true, false) as TabContainer'))
    assert(bootstrap.contains("if main_tabs != null:"))
    assert(not bootstrap.contains("if tabs == null:\n            continue"))

    print("ScreenHost-only and tabless router contract: OK")
