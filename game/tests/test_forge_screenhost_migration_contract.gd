extends Node

func run() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var controller := FileAccess.get_file_as_string("res://scripts/ui/forge_screen.gd")
    var scene := FileAccess.get_file_as_string("res://scenes/ForgeScreen.tscn")
    var main := FileAccess.get_file_as_string("res://scenes/Main.tscn")

    assert(hub.contains('"forja": "res://scenes/ForgeScreen.tscn"'))
    assert(not hub.contains('"forja": "Forja"'))
    assert(not hub.contains("LEGACY_SYSTEM_TABS"))
    assert(not hub.contains("func _show_legacy_screen"))
    assert(scene.contains('[node name="ForgeScreen" type="HSplitContainer"]'))
    assert(scene.contains('[node name="BackToFinca" type="Button" parent="ForgePanel/Header"]'))
    assert(controller.contains("EquipmentManager.get_recipe_ids()"))
    assert(controller.contains("EquipmentManager.craft(selected_recipe_id)"))
    assert(controller.contains("EquipmentManager.get_inventory()"))
    assert(controller.contains("EstateManager.estate_changed.connect(_refresh_recipes)"))
    assert(controller.contains("FincaHubController.show_finca()"))
    assert(controller.contains('event.is_action_pressed("ui_cancel")'))
    assert(main.contains('[node name="Forja" type="HSplitContainer" parent="Margin/VBox/Tabs"]'))

    var packed := load("res://scenes/ForgeScreen.tscn") as PackedScene
    assert(packed != null)
    var instance := packed.instantiate()
    assert(instance != null)
    assert(instance.get_node_or_null("RecipeList") != null)
    assert(instance.get_node_or_null("ForgePanel/Header/BackToFinca") != null)
    assert(instance.get_node_or_null("ForgePanel/RecipeDetails") != null)
    assert(instance.get_node_or_null("ForgePanel/CraftItem") != null)
    assert(instance.get_node_or_null("ForgePanel/Inventory") != null)
    instance.free()

    print("Forge ScreenHost migration contract: OK")
