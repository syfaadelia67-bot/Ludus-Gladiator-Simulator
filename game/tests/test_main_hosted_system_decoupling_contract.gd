extends Node

func run() -> void:
    var main := FileAccess.get_file_as_string("res://scripts/ui/main.gd")

    for forbidden_path in [
        "Tabs/Personal",
        "Tabs/Forja",
        "RosterList",
        "JobSelector",
        "AssignJob",
        "RecipeList",
        "RecipeDetails",
        "CraftItem",
        "ForgePanel/Inventory"
    ]:
        assert(not main.contains(forbidden_path))

    for forbidden_symbol in [
        "selected_person_id",
        "selected_recipe_id",
        "job_ids",
        "_populate_jobs",
        "_on_person_selected",
        "_on_assign_job",
        "_refresh_roster",
        "_refresh_details",
        "_on_recipe_selected",
        "_on_craft_item",
        "_refresh_recipes",
        "_refresh_recipe_details",
        "_refresh_inventory",
        "EquipmentManager."
    ]:
        assert(not main.contains(forbidden_symbol))

    assert(main.contains("MarketManager.market_changed.connect(_refresh_market)"))
    assert(main.contains("EstateManager.estate_changed.connect(_refresh_estate)"))
    assert(main.contains("CombatManager.combat_finished.connect(_on_combat_finished)"))
    assert(main.contains("RosterManager.roster_changed.connect(_on_roster_changed)"))
    assert(main.contains("func _refresh_resources()"))
    assert(main.contains("func _refresh_gladiators()"))

    print("Main hosted Personal and Forge decoupling contract: OK")
