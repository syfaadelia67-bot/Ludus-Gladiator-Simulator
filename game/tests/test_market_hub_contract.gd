extends SceneTree

func _initialize() -> void:
    var scene_text := FileAccess.get_file_as_string("res://scenes/MarketScreen.tscn")
    var screen_text := FileAccess.get_file_as_string("res://scripts/ui/market_screen.gd")
    var market_text := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
    var equipment_text := FileAccess.get_file_as_string("res://scripts/systems/equipment_manager.gd")
    var save_text := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")
    var bootstrap_text := FileAccess.get_file_as_string("res://scripts/ui/all_tabs_ui_bootstrap.gd")

    for required_node in [
        "MarketScreen",
        "ModeButtons",
        "Fighters",
        "Equipment",
        "FightersView",
        "EquipmentView",
        "Refresh",
        "BackToFinca"
    ]:
        assert(scene_text.contains("name=\"%s\"" % required_node) or scene_text.contains("name = \"%s\"" % required_node))

    assert(scene_text.contains("LUCHADORES"))
    assert(scene_text.contains("EQUIPAMIENTO"))
    assert(scene_text.contains("RENOVAR EQUIPAMIENTO · 100"))
    assert(scene_text.contains("facility_market.png"))
    assert(scene_text.contains("equipment_weapon_sword.png"))
    assert(scene_text.contains("ui_resource_gold.png"))

    assert(market_text.contains("const AUTO_REFRESH_WEEKS := 3"))
    assert(market_text.contains("const EQUIPMENT_REFRESH_COST := 100"))
    assert(market_text.contains("func refresh_equipment_market"))
    assert(market_text.contains("func buy_equipment_offer"))
    assert(market_text.contains("week - last_auto_refresh_week < AUTO_REFRESH_WEEKS"))
    assert(market_text.contains("refresh_market(false)"))
    assert(market_text.contains("refresh_equipment_market(false)"))
    assert(market_text.contains("Las ofertas de luchadores se renuevan automáticamente cada 3 semanas"))

    assert(equipment_text.contains("func add_market_item"))
    assert(equipment_text.contains("inventory.append(item)"))
    assert(screen_text.contains("MarketManager.refresh_equipment_market(true)"))
    assert(screen_text.contains("MarketManager.buy_offer"))
    assert(screen_text.contains("MarketManager.buy_equipment_offer"))
    assert(screen_text.contains("MarketManager.get_next_auto_refresh_week"))
    assert(screen_text.contains("FincaHubController.show_finca()"))

    assert(save_text.contains("const SAVE_VERSION := 14"))
    assert(save_text.contains("\"equipment_offers\":MarketManager.equipment_offers"))
    assert(save_text.contains("\"last_auto_refresh_week\":MarketManager.last_auto_refresh_week"))
    assert(save_text.contains("MarketManager.equipment_market_changed.emit()"))

    assert(bootstrap_text.contains("preload(\"res://scenes/MarketScreen.tscn\")"))
    assert(bootstrap_text.contains("_attach_market_screen(tabs)"))
    assert(bootstrap_text.contains("primary_market_screen"))

    var packed := load("res://scenes/MarketScreen.tscn")
    var screen_script := load("res://scripts/ui/market_screen.gd")
    var market_script := load("res://scripts/systems/market_manager.gd")
    assert(packed is PackedScene)
    assert(screen_script != null)
    assert(market_script != null)

    var instance := (packed as PackedScene).instantiate()
    assert(instance.get_node_or_null("ModeButtons/Fighters") is Button)
    assert(instance.get_node_or_null("ModeButtons/Equipment") is Button)
    assert(instance.get_node_or_null("FightersView/OffersPanel/Margin/Content/List") is ItemList)
    assert(instance.get_node_or_null("EquipmentView/OffersPanel/Margin/Content/Header/Refresh") is Button)
    assert(instance.get_node_or_null("EquipmentView/DetailsPanel/Margin/Scroll/Content/Buy") is Button)
    instance.free()

    print("Split fighters and equipment market contract: OK")
    quit()
