extends Node

func run() -> void:
    var catalog_text := FileAccess.get_file_as_string("res://data/buildings.json")
    var scene_text := FileAccess.get_file_as_string("res://scenes/FincaScreen.tscn")
    var controller_text := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
    var parsed: Variant = JSON.parse_string(catalog_text)

    assert(parsed is Array)
    var buildings := parsed as Array
    assert(buildings.size() == 13)

    var demo_count := 0
    for raw_entry in buildings:
        assert(raw_entry is Dictionary)
        var entry := raw_entry as Dictionary
        assert(int(entry.get("max_level", 0)) == 10)
        if bool(entry.get("demo_available", false)):
            demo_count += 1
            assert(int(entry.get("demo_max_level", 0)) == 3)
        else:
            assert(int(entry.get("demo_max_level", -1)) == 0)
    assert(demo_count == 6)

    for building_id in ["dominus_house", "barracks", "training_yard", "forge", "infirmary", "kitchen"]:
        assert(controller_text.contains('"%s"' % building_id))
        assert(controller_text.contains('"%s":' % building_id))

    assert(controller_text.contains('"kitchen":"economia"'))
    assert(controller_text.contains("BLUR_SHADER_CODE"))
    assert(controller_text.contains("hint_screen_texture"))
    assert(controller_text.contains("textureLod"))
    assert(controller_text.contains("func _build_building_modal()"))
    assert(controller_text.contains("func _open_building_modal()"))
    assert(controller_text.contains("func _close_building_modal()"))
    assert(controller_text.contains("button.pressed.connect(_on_hotspot_pressed.bind(building_id))"))
    assert(controller_text.contains("modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP"))
    assert(controller_text.contains("JUEGO COMPLETO · NIVELES 0–10"))
    assert(controller_text.contains("DEMO · NIVEL %d/%d · JUEGO COMPLETO 0–10"))

    assert(scene_text.contains('[node name="QuickAccess" type="PanelContainer" parent="."]'))
    assert(scene_text.contains('[node name="Market" type="Button" parent="QuickAccess/Margin/Center/Row"]'))
    assert(scene_text.contains('[node name="Arena" type="Button" parent="QuickAccess/Margin/Center/Row"]'))
    assert(scene_text.contains('[node name="Personal" type="Button" parent="QuickAccess/Margin/Center/Row"]'))
    assert(scene_text.contains("custom_minimum_size = Vector2(280, 68)"))
    assert(scene_text.contains("text = \"MERCADO\""))
    assert(scene_text.contains("text = \"ARENA\""))
    assert(scene_text.contains("text = \"PERSONAL\""))
    assert(controller_text.contains('market_quick_button.pressed.connect(_open_system.bind("mercado"))'))
    assert(controller_text.contains('arena_quick_button.pressed.connect(_open_system.bind("arena"))'))
    assert(controller_text.contains('personal_quick_button.pressed.connect(_open_system.bind("personal"))'))

    var packed := load("res://scenes/FincaScreen.tscn") as PackedScene
    assert(packed != null)
    var instance := packed.instantiate()
    assert(instance.get_node_or_null("Center/WorldPanel/WorldMargin/WorldArea") != null)
    assert(instance.get_node_or_null("QuickAccess/Margin/Center/Row/Market") is Button)
    assert(instance.get_node_or_null("QuickAccess/Margin/Center/Row/Arena") is Button)
    assert(instance.get_node_or_null("QuickAccess/Margin/Center/Row/Personal") is Button)
    instance.free()

    print("Finca six-building demo, modal blur and quick-access contract: OK")
