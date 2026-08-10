extends SceneTree


func _initialize() -> void:
	var save_text := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")
	var equipment_scene_text := FileAccess.get_file_as_string("res://scenes/EquipmentScreen.tscn")
	var equipment_ui_text := FileAccess.get_file_as_string("res://scripts/ui/equipment_panel_v1.gd")
	var forge_scene_text := FileAccess.get_file_as_string("res://scenes/ForgeScreen.tscn")
	var forge_ui_text := FileAccess.get_file_as_string("res://scripts/ui/forge_screen_v1.gd")

	assert(save_text.contains('person_data["equipped_slots"] = live_person.get_equipped_slots()'))
	assert(save_text.contains("EquipmentManager.reconcile_inventory_ownership()"))
	assert(save_text.contains('equipment_data["canonical_slots_persisted"] = true'))
	assert(not save_text.contains("SAVE_VERSION := 15"))

	assert(equipment_scene_text.contains('path="res://scripts/ui/equipment_panel_v1.gd"'))
	for row_name in [
		"HeadRow",
		"ArmorRow",
		"WeaponRow",
		"ShieldRow",
		"LowerBodyRow",
		"AccessoryRow",
	]:
		assert(equipment_scene_text.contains('name="%s"' % row_name))
	assert(equipment_scene_text.contains("Montura: próximamente"))
	assert(equipment_ui_text.contains('"head"'))
	assert(equipment_ui_text.contains('"torso"'))
	assert(equipment_ui_text.contains('"right_hand"'))
	assert(equipment_ui_text.contains('"left_hand"'))
	assert(equipment_ui_text.contains('"lower_body"'))
	assert(equipment_ui_text.contains('"accessory"'))
	assert(not equipment_ui_text.contains("Ataque final"))
	assert(not equipment_ui_text.contains("Defensa final"))
	assert(equipment_ui_text.contains("no modifican Combat V1"))

	assert(forge_scene_text.contains('path="res://scripts/ui/forge_screen_v1.gd"'))
	assert(forge_scene_text.contains("Fabricación pendiente de balance"))
	assert(forge_ui_text.contains("catálogo parcial legacy"))
	assert(forge_ui_text.contains("fabricación permanece deshabilitada"))
	assert(not forge_ui_text.contains("Fabricaste"))

	var equipment_scene := load("res://scenes/EquipmentScreen.tscn") as PackedScene
	var forge_scene := load("res://scenes/ForgeScreen.tscn") as PackedScene
	assert(equipment_scene != null)
	assert(forge_scene != null)

	var equipment_instance := equipment_scene.instantiate()
	for row_name in [
		"HeadRow",
		"ArmorRow",
		"WeaponRow",
		"ShieldRow",
		"LowerBodyRow",
		"AccessoryRow",
	]:
		assert(equipment_instance.get_node_or_null("%s/Selector" % row_name) is OptionButton)
		assert(equipment_instance.get_node_or_null("%s/Equip" % row_name) is Button)
		assert(equipment_instance.get_node_or_null("%s/Unequip" % row_name) is Button)
	equipment_instance.free()

	var forge_instance := forge_scene.instantiate()
	assert(forge_instance.get_node_or_null("ForgePanel/CraftItem") is Button)
	forge_instance.free()

	print("Equipment V1 Save v14 and six-slot UI contract: OK")
	quit(0)
