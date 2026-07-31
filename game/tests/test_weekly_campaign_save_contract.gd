extends Node

func _ready() -> void:
    var save_source := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")
    var owner_source := FileAccess.get_file_as_string("res://scripts/systems/ludus_owner_manager.gd")

    assert(save_source.contains("\"week\":GameState.week"))
    assert(save_source.contains("GameState.week = maxi"))
    assert(save_source.contains("\"owner\":LudusOwnerManager.export_state()"))
    assert(save_source.contains("\"events\":EventManager.export_state()"))
    assert(save_source.contains("EventManager.import_state"))
    assert(save_source.contains("\"campaign\":CampaignManager.export_state()"))
    assert(save_source.contains("CampaignManager.import_state"))
    assert(save_source.contains("\"combat_history\":CombatHistoryManager.export_state()"))
    assert(save_source.contains("CombatHistoryManager.import_state"))
    assert(save_source.contains("\"next_battle_config\":CombatManager.next_battle_config"))
    assert(save_source.contains("_migrate_battle_config"))
    assert(save_source.contains("\"tournaments\":TournamentManager.export_state()"))
    assert(save_source.contains("TournamentManager.import_state"))
    assert(save_source.contains("\"economy\":EconomyManager.export_state()"))
    assert(save_source.contains("EconomyManager.import_state"))

    assert(owner_source.contains("tutorial_completed"))
    assert(owner_source.contains("export_state"))
    assert(owner_source.contains("import_state"))

    print("Weekly campaign save contract: OK")
    get_tree().quit()
