extends SceneTree

func _initialize() -> void:
    var scene_text := FileAccess.get_file_as_string("res://scenes/MarketScreen.tscn")
    var screen_text := FileAccess.get_file_as_string("res://scripts/ui/market_screen.gd")
    var market_text := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
    var equipment_text := FileAccess.get_file_as_string("res://scripts/systems/equipment_manager.gd")
    var save_text := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")
    var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

    for required_node in [
        "MarketScreen",
        "Landing",
        "FightersCard",
        "EquipmentCard",
        "ContentShell",
        "BackToMarketHome",
        "FightersView",
        "EquipmentView",
        "Refresh",
        "BackToFinca"
    ]:
        assert(scene_text.contains("name=\"%s\"" % required_node) or scene_text.contains("name = \"%s\"" % required_node))

    assert(scene_text.count("type=\"TextureButton\"") >= 2)
    assert(scene_text.contains("custom_minimum_size = Vector2(0, 480)"))
    assert(scene_text.contains("LUCHADORES"))
    assert(scene_text.contains("EQUIPAMIENTO"))
    assert(scene_text.contains("RENOVAR EQUIPAMIENTO · 100"))
    assert(not scene_text.contains("ModeButtons"))
    assert(not scene_text.contains("TabContainer"))

    assert(market_text.contains("const AUTO_REFRESH_WEEKS := 3"))
    assert(market_text.contains("const EQUIPMENT_REFRESH_COST := 100"))
    assert(market_text.contains("func refresh_equipment_market"))
    assert(market_text.contains("func buy_equipment_offer"))
    assert(equipment_text.contains("func add_market_item"))

    assert(screen_text.contains("func _show_market_home"))
    assert(screen_text.contains("func _open_fighters"))
    assert(screen_text.contains("func _open_equipment"))
    assert(screen_text.contains("active_section == \"fighters\""))
    assert(screen_text.contains("active_section == \"equipment\""))
    assert(screen_text.contains("content_shell.visible = true"))
    assert(screen_text.contains("MarketManager.buy_offer"))
    assert(screen_text.contains("MarketManager.buy_equipment_offer"))

    assert(save_text.contains("const SAVE_VERSION := 14"))
    assert(save_text.contains("\"equipment_offers\":MarketManager.equipment_offers"))
    assert(hub_text.contains("\"mercado\": preload(\"res://scenes/MarketScreen.tscn\")"))
    assert(hub_text.contains("_show_hosted_screen"))

    var packed := load("res://scenes/MarketScreen.tscn")
    var screen_script := load("res://scripts/ui/market_screen.gd")
    assert(packed is PackedScene)
    assert(screen_script != null)

    var instance := (packed as PackedScene).instantiate()
    assert(instance.get_node_or_null("Landing/Cards/FightersCard") is TextureButton)
    assert(instance.get_node_or_null("Landing/Cards/EquipmentCard") is TextureButton)
    assert(instance.get_node_or_null("ContentShell/SectionHeader/BackToMarketHome") is Button)
    assert(instance.get_node_or_null("ContentShell/FightersView/OffersPanel/Margin/Content/List") is ItemList)
    assert(instance.get_node_or_null("ContentShell/EquipmentView/OffersPanel/Margin/Content/Header/Refresh") is Button)
    instance.free()

    print("Market cover navigation and purchase stability contract: OK")
    quit()
