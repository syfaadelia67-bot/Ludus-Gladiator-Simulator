extends Node

func run() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var panel := FileAccess.get_file_as_string("res://scripts/ui/equipment_panel.gd")
    var scene := FileAccess.get_file_as_string("res://scenes/EquipmentScreen.tscn")
    var main := FileAccess.get_file_as_string("res://scenes/Main.tscn")

    assert(hub.contains('"equipamiento": "res://scenes/EquipmentScreen.tscn"'))
    assert(not hub.contains('"equipamiento": "Equipamiento"'))
    assert(scene.contains('[node name="EquipmentScreen" type="VBoxContainer"]'))
    assert(scene.contains('[node name="BackToFinca" type="Button" parent="Header"]'))
    assert(scene.contains('script = ExtResource("1")'))
    assert(panel.contains("func _return_to_finca()"))
    assert(panel.contains("FincaHubController.show_finca()"))
    assert(panel.contains('event.is_action_pressed("ui_cancel")'))
    assert(panel.contains("if get_parent() is TabContainer"))
    assert(main.contains('[node name="Equipamiento" type="VBoxContainer" parent="Margin/VBox/Tabs"]'))

    var packed := load("res://scenes/EquipmentScreen.tscn") as PackedScene
    assert(packed != null)
    var instance := packed.instantiate()
    assert(instance != null)
    assert(instance.get_node_or_null("Header/BackToFinca") != null)
    assert(instance.get_node_or_null("GladiatorSelector") != null)
    assert(instance.get_node_or_null("WeaponRow/WeaponSelector") != null)
    assert(instance.get_node_or_null("ArmorRow/ArmorSelector") != null)
    assert(instance.get_node_or_null("ShieldRow/ShieldSelector") != null)
    instance.free()

    print("Equipment ScreenHost migration contract: OK")
