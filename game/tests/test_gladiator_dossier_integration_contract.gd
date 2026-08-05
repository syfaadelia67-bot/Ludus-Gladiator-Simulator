extends SceneTree

func _initialize() -> void:
    var scene_text := FileAccess.get_file_as_string("res://scenes/GladiatorDossierPanel.tscn")
    var dossier_text := FileAccess.get_file_as_string("res://scripts/ui/gladiator_dossier_panel.gd")
    var person_text := FileAccess.get_file_as_string("res://scripts/entities/person.gd")
    var equipment_text := FileAccess.get_file_as_string("res://scripts/systems/equipment_manager.gd")
    var router_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
    var barracks_text := FileAccess.get_file_as_string("res://scripts/ui/barracks_screen.gd")
    var market_manager_text := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
    var market_screen_text := FileAccess.get_file_as_string("res://scripts/ui/market_screen.gd")
    var hud_text := FileAccess.get_file_as_string("res://scripts/ui/unified_hud_shell.gd")
    var save_text := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")

    for tab_node in ["Information", "Statistics", "Equipment", "Skills", "Specialization", "Traits", "Bonds"]:
        assert(scene_text.contains("name=\"%s\"" % tab_node) or scene_text.contains("name = \"%s\"" % tab_node))
    assert(scene_text.contains("text = \"VÍNCULO\""))
    assert(scene_text.contains("ESPECIALIZACIÓN"))
    assert(not scene_text.contains("TabContainer"))
    assert(scene_text.contains("offset_right = -104.0"))
    assert(scene_text.contains("offset_bottom = -86.0"))

    for renderer in [
        "_render_information", "_render_statistics", "_render_equipment", "_render_skills",
        "_render_specialization", "_render_traits", "_render_bonds"
    ]:
        assert(dossier_text.contains("func %s" % renderer))
    assert(dossier_text.contains("func open_gladiator"))
    assert(dossier_text.contains("EquipmentManager.get_available_items_for_slot"))
    assert(dossier_text.contains("EquipmentManager.equip_item_to_slot"))
    assert(dossier_text.contains("RelationshipManager.get_person_relationships"))
    assert(dossier_text.contains("str(other.role) == \"gladiator\""))
    assert(dossier_text.contains("FincaHubController.return_from_gladiator_dossier"))

    for slot_id in ["head", "torso", "right_hand", "left_hand", "lower_body", "accessory", "mount"]:
        assert(person_text.contains("\"%s\"" % slot_id))
        assert(equipment_text.contains("\"%s\"" % slot_id))
    assert(person_text.contains("var equipped_slots: Dictionary"))
    assert(person_text.contains("func set_equipped_item_id"))
    assert(person_text.contains("func synchronize_legacy_equipment"))
    assert(equipment_text.contains("func equip_item_to_slot"))
    assert(equipment_text.contains("func unequip_equipment_slot"))
    assert(equipment_text.contains("func get_available_items_for_slot"))
    assert(equipment_text.contains("func get_equipped_slots"))
    assert(equipment_text.contains("Las monturas estarán disponibles próximamente"))
    assert(equipment_text.contains("antidote_kit"))
    assert(equipment_text.contains("hidden_hook"))
    assert(equipment_text.contains("linen_wraps"))

    assert(router_text.contains("\"gladiator_dossier\": \"res://scenes/GladiatorDossierPanel.tscn\""))
    assert(router_text.contains("func open_gladiator_dossier"))
    assert(router_text.contains("func return_from_gladiator_dossier"))
    assert(router_text.contains("ARENA_MANAGE_PATH"))
    assert(router_text.contains("ARENA_EQUIPMENT_PATH"))
    assert(router_text.contains("_configure_arena_dossier_actions"))
    assert(router_text.contains("typeof(existing_value) != TYPE_CALLABLE"))

    assert(barracks_text.contains("FICHA COMPLETA"))
    assert(barracks_text.contains("func restore_gladiator_context"))
    assert(barracks_text.contains("func _open_dossier"))
    assert(barracks_text.contains("_open_dossier(\"equipment\")"))
    assert(barracks_text.contains("Casco:"))
    assert(barracks_text.contains("Montura: Próximamente"))

    assert(market_manager_text.contains("\"slot\":str(recipe.get(\"slot\", EquipmentManager.get_item_slot(recipe)))"))
    assert(market_screen_text.contains("func _offer_slot"))
    assert(market_screen_text.contains("EquipmentManager.get_slot_label(slot_id)"))
    assert(market_screen_text.contains("Los objetos se equipan desde la ficha individual del gladiador"))

    assert(hud_text.contains("\"gladiator_dossier\":\"Ficha del gladiador\""))
    assert(not hud_text.contains("{\"id\":\"equipamiento\", \"label\":\"Equipamiento\"}"))
    assert(save_text.contains("const SAVE_VERSION := 14"))
    assert(save_text.contains("\"equipped_weapon_id\":person.equipped_weapon_id"))
    assert(save_text.contains("\"equipment\":{\"inventory\":EquipmentManager.inventory.duplicate(true)"))

    var packed := load("res://scenes/GladiatorDossierPanel.tscn")
    var dossier_script := load("res://scripts/ui/gladiator_dossier_panel.gd")
    var person_script := load("res://scripts/entities/person.gd")
    var equipment_script := load("res://scripts/systems/equipment_manager.gd")
    var market_screen_script := load("res://scripts/ui/market_screen.gd")
    assert(packed is PackedScene)
    assert(dossier_script != null)
    assert(person_script != null)
    assert(equipment_script != null)
    assert(market_screen_script != null)

    var instance := (packed as PackedScene).instantiate()
    assert(instance.get_node_or_null("Margin/Main/Header/Margin/Row/Back") is Button)
    assert(instance.get_node_or_null("Margin/Main/Tabs/Margin/Row/Bonds") is Button)
    assert((instance.get_node("Margin/Main/Tabs/Margin/Row/Bonds") as Button).text == "VÍNCULO")
    assert(instance.get_node_or_null("Margin/Main/Body/SummaryPanel") is PanelContainer)
    assert(instance.get_node_or_null("Margin/Main/Body/ContentPanel/Margin/Layout/Scroll/Content") is VBoxContainer)
    instance.free()

    var legacy_person = person_script.new({
        "id": "contract_gladiator",
        "name": "Contrato",
        "role": "gladiator",
        "equipped_weapon_id": "legacy_weapon",
        "equipped_armor_id": "legacy_armor",
        "equipped_shield_id": "legacy_shield"
    })
    assert(legacy_person.get_equipped_item_id("right_hand") == "legacy_weapon")
    assert(legacy_person.get_equipped_item_id("torso") == "legacy_armor")
    assert(legacy_person.get_equipped_item_id("left_hand") == "legacy_shield")
    assert(legacy_person.set_equipped_item_id("head", "helmet_1"))
    assert(legacy_person.get_equipped_item_id("head") == "helmet_1")
    assert(legacy_person.equipped_weapon_id == "legacy_weapon")

    print("Gladiator dossier, bond and seven-slot integration contract: OK")
    quit()
