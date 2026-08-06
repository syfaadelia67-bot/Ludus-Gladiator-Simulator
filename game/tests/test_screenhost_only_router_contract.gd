extends Node

func run() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(hub.contains("const SCREEN_SCENES"))
    assert(hub.contains('"personal": "res://scenes/PersonalScreen.tscn"'))
    assert(hub.contains('"equipamiento": "res://scenes/EquipmentScreen.tscn"'))
    assert(hub.contains('"forja": "res://scenes/ForgeScreen.tscn"'))
    assert(not hub.contains("LEGACY_SYSTEM_TABS"))
    assert(not hub.contains("func _show_legacy_screen"))
    assert(hub.contains("if not SCREEN_SCENES.has(normalized_id):"))
    assert(hub.contains("if not _show_hosted_screen(normalized_id, host, tabs):"))
    assert(hub.contains("tabs.visible = false"))
    assert(hub.contains("tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE"))

    print("ScreenHost-only router contract: OK")
