extends Node


func run() -> void:
	var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
	var panel := FileAccess.get_file_as_string("res://scripts/ui/equipment_panel_v1.gd")
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
	assert(main.contains('[node name="ScreenHost" type="Control" parent="Margin/VBox"]'))
	assert(not main.contains('[node name="Tabs" type="TabContainer"'))
	assert(not main.contains('parent="Margin/VBox/Tabs/Equipamiento'))

	var packed := load("res://scenes/EquipmentScreen.tscn") as PackedScene
	assert(packed != null)
	var instance := packed.instantiate()
	assert(instance != null)
	assert(instance.get_node_or_null("Header/BackToFinca") != null)
	assert(instance.get_node_or_null("GladiatorSelector") != null)
	for row_name in [
		"HeadRow",
		"ArmorRow",
		"WeaponRow",
		"ShieldRow",
		"LowerBodyRow",
		"AccessoryRow",
	]:
		assert(instance.get_node_or_null("%s/Selector" % row_name) is OptionButton)
		assert(instance.get_node_or_null("%s/Equip" % row_name) is Button)
		assert(instance.get_node_or_null("%s/Unequip" % row_name) is Button)
	assert(instance.get_parent() == null)
	instance.free()

	print("Equipment six-slot ScreenHost migration contract: OK")
