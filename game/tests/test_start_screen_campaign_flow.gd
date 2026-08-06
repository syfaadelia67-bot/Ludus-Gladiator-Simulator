extends Node

const START_SCREEN_PATH := "res://scripts/ui/start_screen_controller.gd"
const OWNER_MANAGER_PATH := "res://scripts/systems/ludus_owner_manager.gd"
const NEW_CAMPAIGN_PATH := "res://scripts/core/new_campaign_coordinator.gd"
const PROJECT_PATH := "res://project.godot"

func run() -> void:
    var start_screen := FileAccess.get_file_as_string(START_SCREEN_PATH)
    var owner_manager := FileAccess.get_file_as_string(OWNER_MANAGER_PATH)
    var new_campaign := FileAccess.get_file_as_string(NEW_CAMPAIGN_PATH)
    var project := FileAccess.get_file_as_string(PROJECT_PATH)

    for fragment in [
        "func _show_main_menu()", "func _continue_campaign()", "func _show_owner_creation(",
        "func _start_new_campaign()", "func _inspect_save()", 'save_inspection.get("loadable"',
        "SaveManager.load_game()", "NewCampaignCoordinator.reset_campaign_state()",
        "LudusOwnerManager.configure_owner", "START_NEW_CAMPAIGN_TITLE", "START_BEGIN_CAMPAIGN"
    ]:
        assert(start_screen.contains(fragment), "Falta contrato de inicio: %s" % fragment)

    for fragment in [
        "const LEGACY_PROFILE_PATH", "func reset_profile()", "func export_state()",
        "func import_state(data: Dictionary)", "func get_origin_ids()", "tutorial_progress"
    ]:
        assert(owner_manager.contains(fragment), "Falta contrato de propietario: %s" % fragment)

    for fragment in [
        "func reset_campaign_state()", "SaveManager.autosave_enabled = false", '"day": 1',
        '"people": []', "SaveManager._apply_payload(reset_payload)",
        "SaveManager.autosave_enabled = previous_autosave"
    ]:
        assert(new_campaign.contains(fragment), "Falta contrato de reinicio: %s" % fragment)

    assert(project.contains("NewCampaignCoordinator="))
    assert(project.contains("StartScreenController="))

    var origin_ids := LudusOwnerManager.get_origin_ids()
    assert(origin_ids.size() >= 4)
    for origin_id in origin_ids:
        var origin := LudusOwnerManager.get_origin(origin_id)
        assert(not str(origin.get("name", "")).is_empty())
        assert(not str(origin.get("description", "")).is_empty())
        assert(origin.get("bonuses", null) is Dictionary)

    print("Localized start screen and campaign creation flow contract: OK")
