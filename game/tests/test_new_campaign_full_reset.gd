extends Node

func _ready() -> void:
    var owner_source := FileAccess.get_file_as_string("res://scripts/systems/ludus_owner_manager.gd")
    var start_source := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")

    assert(owner_source.contains("func _reset_campaign_for_new_owner()"))
    assert(owner_source.contains("_reset_campaign_for_new_owner()"))
    assert(owner_source.contains("GameState.day = 1"))
    assert(owner_source.contains("GameState.denarii = 500"))
    assert(owner_source.contains("RosterManager.people.clear()"))
    assert(owner_source.contains("RosterManager._seed_initial_roster()"))
    assert(owner_source.contains("EstateManager.import_levels({})"))
    assert(owner_source.contains("EquipmentManager.inventory.clear()"))
    assert(owner_source.contains("MarketManager.refresh_market(false)"))
    assert(owner_source.contains("RivalManager._seed_rivals()"))
    assert(owner_source.contains("CombatHistoryManager.import_state({})"))
    assert(owner_source.contains("EventManager.import_state({})"))
    assert(owner_source.contains("CampaignManager.import_state({})"))
    assert(owner_source.contains("TransferManager.import_state({})"))
    assert(owner_source.find("_reset_campaign_for_new_owner()") < owner_source.find("_apply_origin_bonuses_once()"))
    assert(start_source.contains("NewCampaignCoordinator.reset_campaign_state()"))
    assert(start_source.contains("LudusOwnerManager.configure_owner"))

    print("New campaign full reset contract: OK")
    get_tree().quit()
