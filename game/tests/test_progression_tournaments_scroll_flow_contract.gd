extends SceneTree

func _initialize() -> void:
    var progression_scene_text := FileAccess.get_file_as_string("res://scenes/ProgressionPanel.tscn")
    var tournaments_scene_text := FileAccess.get_file_as_string("res://scenes/TournamentsPanel.tscn")
    var progression_script_text := FileAccess.get_file_as_string("res://scripts/ui/progression_panel.gd")
    var tournaments_script_text := FileAccess.get_file_as_string("res://scripts/ui/tournaments_panel.gd")
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    assert(progression_scene_text.contains("[node name=\"Navigation\" type=\"HBoxContainer\""))
    assert(progression_scene_text.contains("[node name=\"BackToFinca\" type=\"Button\" parent=\"Navigation\"]"))
    assert(progression_scene_text.contains("[node name=\"Scroll\" type=\"ScrollContainer\""))
    assert(progression_scene_text.contains("[node name=\"Content\" type=\"VBoxContainer\" parent=\"Scroll\"]"))
    assert(progression_script_text.contains("$Scroll/Content/GladiatorSelector"))
    assert(progression_script_text.contains("FincaHubController.show_finca()"))
    assert(progression_script_text.contains("ui_cancel"))

    assert(tournaments_scene_text.contains("[node name=\"Navigation\" type=\"HBoxContainer\""))
    assert(tournaments_scene_text.contains("[node name=\"BackToFinca\" type=\"Button\" parent=\"Navigation\"]"))
    assert(tournaments_scene_text.contains("[node name=\"Scroll\" type=\"ScrollContainer\""))
    assert(tournaments_scene_text.contains("[node name=\"Content\" type=\"VBoxContainer\" parent=\"Scroll\"]"))
    assert(tournaments_script_text.contains("$Scroll/Content/TournamentContent/EventList"))
    assert(tournaments_script_text.contains("FincaHubController.show_finca()"))
    assert(tournaments_script_text.contains("ui_cancel"))

    assert(hub_text.contains("\"torneos\": \"Torneos\""))
    assert(hub_text.contains("\"progresion\": \"Progresión\""))

    var progression_scene := load("res://scenes/ProgressionPanel.tscn") as PackedScene
    var tournaments_scene := load("res://scenes/TournamentsPanel.tscn") as PackedScene
    assert(progression_scene != null)
    assert(tournaments_scene != null)

    var progression_instance := progression_scene.instantiate()
    var tournaments_instance := tournaments_scene.instantiate()
    assert(progression_instance.get_node_or_null("Navigation/BackToFinca") != null)
    assert(progression_instance.get_node_or_null("Scroll/Content/RetiredHistory") != null)
    assert(tournaments_instance.get_node_or_null("Navigation/BackToFinca") != null)
    assert(tournaments_instance.get_node_or_null("Scroll/Content/TournamentContent/Right/Contracts") != null)
    progression_instance.free()
    tournaments_instance.free()

    print("Progression and tournaments scroll flow contract: OK")
    quit()
