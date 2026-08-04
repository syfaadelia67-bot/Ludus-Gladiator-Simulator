extends SceneTree

func _initialize() -> void:
    var scene_text := FileAccess.get_file_as_string("res://scenes/CampaignPanel.tscn")
    var script_text := FileAccess.get_file_as_string("res://scripts/ui/campaign_panel.gd")

    for required_node in ["Navigation", "BackToFinca", "Scroll", "Content", "ObjectivesList"]:
        assert(scene_text.contains("name=\"%s\"" % required_node) or scene_text.contains("name = \"%s\"" % required_node))

    assert(scene_text.contains("horizontal_scroll_mode = 0"))
    assert(scene_text.contains("size_flags_horizontal = 3"))
    assert(scene_text.contains("fit_content = true"))
    assert(not scene_text.contains("name=\"Objectives\" type=\"RichTextLabel\""))
    assert(not scene_text.contains("name = \"Objectives\" type = \"RichTextLabel\""))

    assert(script_text.contains("$Scroll/Content/ObjectivesList"))
    assert(script_text.contains("_rebuild_objectives()"))
    assert(script_text.contains("_add_objective_card"))
    assert(script_text.contains("TextServer.AUTOWRAP_WORD_SMART"))
    assert(script_text.contains("FincaHubController.show_finca()"))

    var campaign_scene := load("res://scenes/CampaignPanel.tscn")
    var campaign_script := load("res://scripts/ui/campaign_panel.gd")
    assert(campaign_scene is PackedScene)
    assert(campaign_script != null)

    var instance := (campaign_scene as PackedScene).instantiate()
    assert(instance.get_node_or_null("Navigation/BackToFinca") != null)
    assert(instance.get_node_or_null("Scroll") is ScrollContainer)
    assert(instance.get_node_or_null("Scroll/Content") is VBoxContainer)
    assert(instance.get_node_or_null("Scroll/Content/ObjectivesList") is VBoxContainer)
    instance.free()

    print("Campaign responsive layout contract: OK")
    quit()
