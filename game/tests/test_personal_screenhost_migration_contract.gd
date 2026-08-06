extends Node

func run() -> void:
    var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var controller := FileAccess.get_file_as_string("res://scripts/ui/personal_screen.gd")
    var scene := FileAccess.get_file_as_string("res://scenes/PersonalScreen.tscn")
    var main := FileAccess.get_file_as_string("res://scenes/Main.tscn")

    assert(hub.contains('"personal": "res://scenes/PersonalScreen.tscn"'))
    assert(not hub.contains('"personal": "Personal"'))
    assert(scene.contains('[node name="PersonalScreen" type="HSplitContainer"]'))
    assert(scene.contains('[node name="BackToFinca" type="Button" parent="Left/Header"]'))
    assert(scene.contains('[node name="RosterList" type="ItemList" parent="Left"]'))
    assert(scene.contains('[node name="OpenDossier" type="Button" parent="Left"]'))
    assert(controller.contains("func restore_context(context: Dictionary)"))
    assert(controller.contains("FincaHubController.open_gladiator_dossier"))
    assert(controller.contains('"system_id": "personal"'))
    assert(controller.contains('event.is_action_pressed("ui_cancel")'))
    assert(controller.contains("RosterManager.assign_job"))
    assert(main.contains('[node name="ScreenHost" type="Control" parent="Margin/VBox"]'))
    assert(not main.contains('[node name="Tabs" type="TabContainer"'))
    assert(not main.contains('parent="Margin/VBox/Tabs/Personal'))

    var packed := load("res://scenes/PersonalScreen.tscn") as PackedScene
    assert(packed != null)
    var instance := packed.instantiate()
    assert(instance != null)
    assert(instance.get_node_or_null("Left/Header/BackToFinca") != null)
    assert(instance.get_node_or_null("Left/RosterList") != null)
    assert(instance.get_node_or_null("Left/JobRow/JobSelector") != null)
    assert(instance.get_node_or_null("Left/OpenDossier") != null)
    instance.free()

    print("Personal ScreenHost migration contract: OK")
