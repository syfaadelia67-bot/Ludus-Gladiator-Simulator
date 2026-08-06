extends SceneTree

func _initialize() -> void:
    var rivals_scene_text := FileAccess.get_file_as_string("res://scenes/RivalsPanel.tscn")
    var economy_scene_text := FileAccess.get_file_as_string("res://scenes/EconomyPanel.tscn")
    var rivals_script_text := FileAccess.get_file_as_string("res://scripts/ui/rivals_panel.gd")
    var economy_script_text := FileAccess.get_file_as_string("res://scripts/ui/economy_panel.gd")
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(rivals_scene_text.contains("[node name=\"Navigation\""))
    assert(rivals_scene_text.contains("[node name=\"BackToFinca\""))
    assert(rivals_scene_text.contains("[node name=\"Scroll\" type=\"ScrollContainer\""))
    assert(rivals_scene_text.contains("parent=\"Scroll/Content\""))
    assert(rivals_script_text.contains("$Navigation/BackToFinca"))
    assert(rivals_script_text.contains("$Scroll/Content/RivalOperations"))
    assert(rivals_script_text.contains("FincaHubController.show_finca()"))
    assert(rivals_script_text.contains("ui_cancel"))

    assert(economy_scene_text.contains("[node name=\"Navigation\""))
    assert(economy_scene_text.contains("[node name=\"BackToFinca\""))
    assert(economy_scene_text.contains("[node name=\"Scroll\" type=\"ScrollContainer\""))
    assert(economy_scene_text.contains("parent=\"Scroll/Content\""))
    assert(economy_script_text.contains("$Navigation/BackToFinca"))
    assert(economy_script_text.contains("$Scroll/Content/Summary"))
    assert(economy_script_text.contains("FincaHubController.show_finca()"))
    assert(economy_script_text.contains("ui_cancel"))

    assert(hub_text.contains("\"rivales\": \"res://scenes/RivalsPanel.tscn\""))
    assert(hub_text.contains("\"economia\": \"res://scenes/EconomyPanel.tscn\""))

    var rivals_scene := load("res://scenes/RivalsPanel.tscn") as PackedScene
    var economy_scene := load("res://scenes/EconomyPanel.tscn") as PackedScene
    assert(rivals_scene != null)
    assert(economy_scene != null)

    var rivals_instance := rivals_scene.instantiate()
    var economy_instance := economy_scene.instantiate()
    assert(rivals_instance.get_node_or_null("Navigation/BackToFinca") != null)
    assert(rivals_instance.get_node_or_null("Scroll/Content/RivalOperations") != null)
    assert(economy_instance.get_node_or_null("Navigation/BackToFinca") != null)
    assert(economy_instance.get_node_or_null("Scroll/Content/Columns") != null)
    rivals_instance.free()
    economy_instance.free()

    print("Rivals and economy hosted scroll flow contract: OK")
    quit()
