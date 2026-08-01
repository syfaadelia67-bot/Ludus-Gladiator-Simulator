extends Node

func _ready() -> void:
    var controller := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")
    var scene := FileAccess.get_file_as_string("res://scenes/Main.tscn")

    assert(controller.contains("func show_finca()"))
    assert(controller.contains("func open_system(system_id: String)"))
    assert(controller.contains("func get_current_system_id()"))
    assert(controller.contains("\"finca\": \"Finca\""))
    assert(controller.contains("SaveManager.load_completed.connect(_on_campaign_entered)"))
    assert(controller.contains("NewCampaignCoordinator.campaign_reset_completed.connect(_on_campaign_entered)"))
    assert(controller.contains("call_deferred(\"_open_finca_when_ready\")"))
    assert(controller.contains("tabs.current_tab = tab_index"))

    assert(scene.contains("[node name=\"Finca\""))
    assert(scene.contains("[node name=\"Tabs\" type=\"TabContainer\""))
    assert(project.contains("FincaHubController=\"*res://scripts/ui/finca_hub_controller.gd\""))
    assert(project.find("CompletedCampaignReadOnlyPresenter=") < project.find("FincaHubController="))
    assert(project.find("FincaHubController=") < project.find("StartScreenController="))

    print("Finca hub navigation contract: OK")
    get_tree().quit()
