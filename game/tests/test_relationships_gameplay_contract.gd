extends SceneTree

func _initialize() -> void:
    var manager_text := FileAccess.get_file_as_string("res://scripts/systems/relationship_manager.gd")
    var scene_text := FileAccess.get_file_as_string("res://scenes/RelationshipsPanel.tscn")
    var screen_text := FileAccess.get_file_as_string("res://scripts/ui/relationships_panel.gd")
    var hud_scene_text := FileAccess.get_file_as_string("res://scenes/UnifiedHudShell.tscn")
    var hud_script_text := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")
    var save_text := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")

    assert(manager_text.contains("const MAX_WEEKLY_INTERVENTIONS := 2"))
    assert(manager_text.contains("const PAIR_INTERACTION_COOLDOWN_WEEKS := 2"))
    assert(manager_text.contains("var last_processed_week: int = 0"))
    assert(manager_text.contains("if last_processed_week == week"))
    assert(manager_text.contains("each person creates at most one automatic social"))
    assert(manager_text.contains("func get_social_overview"))
    assert(manager_text.contains("func get_available_interactions"))
    assert(manager_text.contains("func can_register_interaction"))
    assert(manager_text.contains("func get_tension"))
    assert(manager_text.contains("func _derive_tone"))
    assert(manager_text.contains("favor_actor"))
    assert(manager_text.contains("favor_target"))
    assert(manager_text.contains("actor_id"))
    assert(manager_text.contains("target_id"))
    assert(manager_text.contains("created_week"))
    assert(manager_text.contains("resolved_week"))
    assert(manager_text.contains("a.traits.has(\"popular\")"))
    assert(not manager_text.contains("traits.has(\"ambitious\")"))
    assert(manager_text.contains("last_interaction_week"))
    assert(manager_text.contains("Semana %d"))

    var enemy_index := manager_text.find("return \"enemistad\"")
    var friendship_index := manager_text.find("return \"amistad\"")
    assert(enemy_index >= 0 and friendship_index >= 0 and enemy_index < friendship_index)

    for required_node in [
        "RelationshipsPanel", "BackToFinca", "Overview", "IncidentPanel", "PeopleList",
        "BondCards", "DetailPanel", "Actions", "RecentEvents", "Interventions"
    ]:
        assert(scene_text.contains("name=\"%s\"" % required_node) or scene_text.contains("name = \"%s\"" % required_node))

    assert(scene_text.contains("VÍNCULOS DEL LUDUS"))
    assert(scene_text.contains("COHESIÓN"))
    assert(scene_text.contains("TENSIÓN"))
    assert(not scene_text.contains("OptionButton"))
    assert(not scene_text.contains("FirstSelect"))
    assert(not scene_text.contains("SecondSelect"))

    assert(screen_text.contains("RelationshipManager.get_social_overview()"))
    assert(screen_text.contains("RelationshipManager.get_person_relationships"))
    assert(screen_text.contains("RelationshipManager.get_available_interactions"))
    assert(screen_text.contains("FincaHubController.show_finca()"))
    assert(not screen_text.contains("_selected_id"))

    assert(hud_scene_text.contains("name=\"Social\" type=\"Label\""))
    assert(hud_scene_text.contains("tooltip_text = \"Vínculos\""))
    assert(hud_script_text.contains("\"relaciones\":\"Vínculos\""))
    assert(hud_script_text.contains("RelationshipManager.relationships_changed.connect"))
    assert(hud_script_text.contains("RelationshipManager.get_social_overview()"))
    assert(save_text.contains("const SAVE_VERSION := 14"))

    var packed := load("res://scenes/RelationshipsPanel.tscn")
    var manager_script := load("res://scripts/systems/relationship_manager.gd")
    var screen_script := load("res://scripts/ui/relationships_panel.gd")
    assert(packed is PackedScene)
    assert(manager_script != null)
    assert(screen_script != null)

    var instance := (packed as PackedScene).instantiate()
    assert(instance.get_node_or_null("Margin/Main/Body/PeoplePanel/Margin/Content/PeopleList") is ItemList)
    assert(instance.get_node_or_null("Margin/Main/Body/BondsPanel/Margin/Content/Scroll/BondCards") is VBoxContainer)
    assert(instance.get_node_or_null("Margin/Main/IncidentPanel/Margin/Content/Choices") is HBoxContainer)
    assert(instance.get_node_or_null("Margin/Main/Body/DetailPanel/Margin/Scroll/Content/Actions") is VBoxContainer)
    instance.free()

    print("Ludus bonds weekly gameplay contract: OK")
    quit()
