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
        "BondCards", "DetailPanel", "Actions", "Status", "RecentEvents", "Interventions"
    ]:
        assert(scene_text.contains("name=\"%s\"" % required_node) or scene_text.contains("name = \"%s\"" % required_node))

    assert(scene_text.contains("VÍNCULOS DEL LUDUS"))
    assert(scene_text.contains("COHESIÓN"))
    assert(scene_text.contains("TENSIÓN"))
    assert(scene_text.find("name=\"Status\"") < scene_text.find("name=\"ActionsTitle\""))
    assert(not scene_text.contains("OptionButton"))
    assert(not scene_text.contains("FirstSelect"))
    assert(not scene_text.contains("SecondSelect"))

    assert(screen_text.contains("RelationshipManager.get_social_overview()"))
    assert(screen_text.contains("RelationshipManager.get_person_relationships"))
    assert(screen_text.contains("RelationshipManager.get_available_interactions"))
    assert(screen_text.contains("func _attempt_interaction"))
    assert(screen_text.contains("NO DISPONIBLE"))
    assert(screen_text.contains("INTERVENCIÓN APLICADA"))
    assert(screen_text.contains("interaction_in_progress"))
    assert(screen_text.contains("refresh_pending"))
    assert(not screen_text.contains("button.disabled = not bool(action.get(\"allowed\""))
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
    assert(instance.get_node_or_null("Margin/Main/Body/DetailPanel/Margin/Scroll/Content/Status") is Label)
    instance.free()

    _test_intervention_changes_gameplay_state()

    print("Ludus bonds intervention feedback and gameplay contract: OK")
    quit()

func _test_intervention_changes_gameplay_state() -> void:
    var people := RosterManager.get_people()
    assert(people.size() >= 2)
    var a = people[0]
    var b = people[1]
    var a_id := str(a.id)
    var b_id := str(b.id)

    var previous_manager_state := RelationshipManager.export_state()
    var previous_a_fatigue := int(a.fatigue)
    var previous_b_fatigue := int(b.fatigue)
    var previous_a_injury_days := int(a.injury_days)
    var previous_b_injury_days := int(b.injury_days)

    a.fatigue = 0
    b.fatigue = 0
    a.injury_days = 0
    b.injury_days = 0
    RelationshipManager.relationships.clear()
    RelationshipManager.interventions_week = GameState.get_week()
    RelationshipManager.interventions_used = 0

    var before := RelationshipManager.ensure_relationship(a_id, b_id).duplicate(true)
    var result := RelationshipManager.register_interaction(a_id, b_id, "train_together")
    var after := RelationshipManager.get_relationship(a_id, b_id)

    assert(bool(result.get("success", false)))
    assert(not str(result.get("description", "")).is_empty())
    assert(int(result.get("interventions_remaining", -1)) == 1)
    assert(int(after.get("affinity", 0)) == int(before.get("affinity", 0)) + 3)
    assert(int(after.get("respect", 0)) == int(before.get("respect", 0)) + 4)
    assert(int(a.fatigue) == 6)
    assert(int(b.fatigue) == 6)

    a.fatigue = previous_a_fatigue
    b.fatigue = previous_b_fatigue
    a.injury_days = previous_a_injury_days
    b.injury_days = previous_b_injury_days
    RelationshipManager.import_state(previous_manager_state)
