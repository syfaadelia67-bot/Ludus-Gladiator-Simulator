extends Node

func run() -> void:
    var main := FileAccess.get_file_as_string("res://scripts/ui/main.gd")

    for forbidden_path in [
        "Tabs/Personal",
        "Tabs/Forja",
        "Tabs/Mercado",
        "Tabs/Arena",
        "RosterList",
        "JobSelector",
        "AssignJob",
        "RecipeList",
        "RecipeDetails",
        "CraftItem",
        "ForgePanel/Inventory",
        "MarketList",
        "MarketDetails",
        "BuyOffer",
        "Setup/GladiatorSelector",
        "Setup/TacticSelector",
        "StartDuel",
        "CombatLog"
    ]:
        assert(not main.contains(forbidden_path))

    for forbidden_symbol in [
        "selected_person_id",
        "selected_recipe_id",
        "selected_offer_id",
        "job_ids",
        "gladiator_ids",
        "tactic_ids",
        "_populate_jobs",
        "_populate_tactics",
        "_on_person_selected",
        "_on_assign_job",
        "_refresh_roster",
        "_refresh_details",
        "_on_recipe_selected",
        "_on_craft_item",
        "_refresh_recipes",
        "_refresh_recipe_details",
        "_refresh_inventory",
        "_on_offer_selected",
        "_on_buy_offer",
        "_refresh_market",
        "_refresh_market_details",
        "_on_start_duel",
        "_on_combat_finished",
        "_refresh_gladiators",
        "EquipmentManager.",
        "MarketManager.",
        "CombatManager."
    ]:
        assert(not main.contains(forbidden_symbol))

    assert(main.contains("EstateManager.estate_changed.connect(_refresh_estate)"))
    assert(main.contains("RosterManager.roster_changed.connect(_refresh_resources)"))
    assert(main.contains("GameState.resources_changed.connect(_refresh_resources)"))
    assert(main.contains("func _on_advance_week()"))
    assert(main.contains("GameState.advance_week()"))
    assert(main.contains("func _refresh_resources()"))
    assert(main.contains("refresh_market_button.visible = false"))
    assert(main.contains("refresh_market_button.mouse_filter = Control.MOUSE_FILTER_IGNORE"))

    print("Main hosted Personal, Forge, Market and Arena decoupling contract: OK")
