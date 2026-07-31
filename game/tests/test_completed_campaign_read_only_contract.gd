extends Node

func _ready() -> void:
    var game_state := FileAccess.get_file_as_string("res://scripts/core/game_state.gd")
    var market := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
    var equipment := FileAccess.get_file_as_string("res://scripts/systems/equipment_manager.gd")
    var combat := FileAccess.get_file_as_string("res://scripts/systems/combat_manager_weekly.gd")

    assert(game_state.contains("CampaignManager.campaign_over"))
    assert(game_state.contains("campaign_action_blocked.emit"))
    assert(game_state.find("CampaignManager.campaign_over") < game_state.find("var report :="))

    assert(market.contains("La campaña terminó. El mercado está disponible solo para consulta."))
    assert(market.contains("La campaña terminó. No se pueden realizar nuevas compras."))
    assert(market.contains("func get_offers()"))

    assert(equipment.contains("La campaña terminó. La forja está disponible solo para consulta."))
    assert(equipment.contains("func get_inventory()"))

    assert(combat.contains("func simulate_duel"))
    assert(combat.contains("CampaignManager.campaign_over"))
    assert(combat.contains("consultar resultados e historial"))
    assert(combat.contains("return super.simulate_duel(gladiator_id, tactic)"))
    assert(combat.contains("func get_current_event_details()"))

    print("Completed campaign read-only contract: OK")
    get_tree().quit()
