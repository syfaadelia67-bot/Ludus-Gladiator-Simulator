extends Node

func _ready() -> void:
    var coordinator := FileAccess.get_file_as_string("res://scripts/core/new_campaign_coordinator.gd")
    var start_screen := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(coordinator.contains("func reset_campaign_state()"))
    assert(coordinator.contains("var reset_in_progress: bool = false"))
    assert(coordinator.contains("if reset_in_progress:"))
    assert(coordinator.contains("Ya se está preparando una nueva campaña."))
    assert(coordinator.contains("SaveManager.autosave_enabled = false"))
    assert(coordinator.contains("SaveManager.delete_save()"))
    assert(coordinator.contains("\"day\": 1"))
    assert(coordinator.contains("\"week\": 1"))
    assert(coordinator.contains("\"denarii\": 500"))
    assert(coordinator.contains("\"people\": []"))
    assert(coordinator.contains("\"combat_history\": {\"entries\": []}"))
    assert(coordinator.contains("SaveManager._apply_payload(reset_payload)"))
    assert(coordinator.contains("SaveManager.autosave_enabled = previous_autosave"))
    assert(coordinator.contains("reset_in_progress = false"))

    assert(start_screen.contains("NewCampaignCoordinator.reset_campaign_state()"))
    assert(start_screen.find("NewCampaignCoordinator.reset_campaign_state()") < start_screen.find("LudusOwnerManager.configure_owner"))
    assert(project.contains("NewCampaignCoordinator=\"*res://scripts/core/new_campaign_coordinator.gd\""))
    assert(project.find("SaveManager=") < project.find("NewCampaignCoordinator="))

    print("New campaign reset contract: OK")
    get_tree().quit()
