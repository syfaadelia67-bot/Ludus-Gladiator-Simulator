extends VBoxContainer

const COVER_CARD_SIZE := Vector2(850, 478)

@onready var back_button: Button = $Header/BackToFinca
@onready var rotation_label: Label = $Header/Rotation
@onready var landing: VBoxContainer = $Landing
@onready var cards_row: HBoxContainer = $Landing/Cards
@onready var fighters_card: TextureButton = $Landing/Cards/FightersCard
@onready var equipment_card: TextureButton = $Landing/Cards/EquipmentCard
@onready var content_shell: VBoxContainer = $ContentShell
@onready var back_to_market_home: Button = $ContentShell/SectionHeader/BackToMarketHome
@onready var section_title: Label = $ContentShell/SectionHeader/SectionTitle
@onready var feedback: Label = $ContentShell/Feedback

@onready var fighters_view: HSplitContainer = $ContentShell/FightersView
@onready var fighter_list: ItemList = $ContentShell/FightersView/OffersPanel/Margin/Content/List
@onready var fighter_details: RichTextLabel = $ContentShell/FightersView/DetailsPanel/Margin/Scroll/Content/Details
@onready var fighter_buy_button: Button = $ContentShell/FightersView/DetailsPanel/Margin/Scroll/Content/Buy

@onready var equipment_view: HSplitContainer = $ContentShell/EquipmentView
@onready var equipment_list: ItemList = $ContentShell/EquipmentView/OffersPanel/Margin/Content/List
@onready var equipment_refresh_button: Button = $ContentShell/EquipmentView/OffersPanel/Margin/Content/Header/Refresh
@onready var equipment_details: RichTextLabel = $ContentShell/EquipmentView/DetailsPanel/Margin/Scroll/Content/Details
@onready var equipment_buy_button: Button = $ContentShell/EquipmentView/DetailsPanel/Margin/Scroll/Content/Buy

var selected_fighter_offer_id := ""
var selected_equipment_offer_id := ""
var active_section := ""

func _ready() -> void:
    back_button.pressed.connect(_return_to_finca)
    fighters_card.pressed.connect(_open_fighters)
    equipment_card.pressed.connect(_open_equipment)
    back_to_market_home.pressed.connect(_show_market_home)
    fighter_list.item_selected.connect(_on_fighter_selected)
    equipment_list.item_selected.connect(_on_equipment_selected)
    fighter_buy_button.pressed.connect(_buy_selected_fighter)
    equipment_buy_button.pressed.connect(_buy_selected_equipment)
    equipment_refresh_button.pressed.connect(_refresh_equipment_only)
    visibility_changed.connect(_on_visibility_changed)

    MarketManager.market_changed.connect(_refresh_fighter_offers)
    MarketManager.equipment_market_changed.connect(_refresh_equipment_offers)
    MarketManager.purchase_completed.connect(_on_fighter_purchase_completed)
    MarketManager.purchase_failed.connect(_on_fighter_purchase_failed)
    MarketManager.equipment_purchase_completed.connect(_on_equipment_purchase_completed)
    MarketManager.equipment_purchase_failed.connect(_on_equipment_purchase_failed)
    GameState.resources_changed.connect(_refresh_controls)
    GameState.week_advanced.connect(func(_week: int): _refresh_all())

    _configure_cover_cards()
    _show_market_home()
    _refresh_all()

func _configure_cover_cards() -> void:
    cards_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    for card in [fighters_card, equipment_card]:
        card.custom_minimum_size = COVER_CARD_SIZE
        card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _unhandled_key_input(event: InputEvent) -> void:
    if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
        return
    if content_shell.visible:
        _show_market_home()
    else:
        _return_to_finca()
    get_viewport().set_input_as_handled()

func _on_visibility_changed() -> void:
    if is_visible_in_tree():
        _show_market_home()
        _refresh_all()

func _show_market_home() -> void:
    active_section = ""
    landing.visible = true
    landing.mouse_filter = Control.MOUSE_FILTER_PASS
    content_shell.visible = false
    content_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback.text = ""

func _open_fighters() -> void:
    active_section = "fighters"
    landing.visible = false
    landing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content_shell.visible = true
    content_shell.mouse_filter = Control.MOUSE_FILTER_PASS
    fighters_view.visible = true
    fighters_view.mouse_filter = Control.MOUSE_FILTER_PASS
    equipment_view.visible = false
    equipment_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    section_title.text = "MERCADO DE LUCHADORES"
    feedback.text = "La renovación de luchadores ocurre automáticamente cada tres semanas."
    _refresh_fighter_offers()

func _open_equipment() -> void:
    active_section = "equipment"
    landing.visible = false
    landing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content_shell.visible = true
    content_shell.mouse_filter = Control.MOUSE_FILTER_PASS
    fighters_view.visible = false
    fighters_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    equipment_view.visible = true
    equipment_view.mouse_filter = Control.MOUSE_FILTER_PASS
    section_title.text = "MERCADO DE EQUIPAMIENTO"
    feedback.text = "Podés renovar únicamente esta sección por 100 denarios. Los objetos se equipan desde la ficha individual del gladiador."
    _refresh_equipment_offers()

func _refresh_all() -> void:
    _refresh_rotation_label()
    _refresh_fighter_offers()
    _refresh_equipment_offers()
    _refresh_controls()

func _refresh_rotation_label() -> void:
    rotation_label.text = "RENOVACIÓN GENERAL · SEMANA %d\nFALTAN %d SEMANA(S)" % [
        MarketManager.get_next_auto_refresh_week(),
        MarketManager.get_weeks_until_auto_refresh()
    ]

func _refresh_fighter_offers() -> void:
    var previous_id := selected_fighter_offer_id
    fighter_list.clear()
    var offers := MarketManager.get_offers()
    for index in range(offers.size()):
        var offer: Dictionary = offers[index]
        fighter_list.add_item("%s · %s%s · %d denarios" % [
            offer.get("name", "Sin nombre"),
            _role_label(str(offer.get("role", "slave"))),
            " · ÚNICO" if bool(offer.get("unique", false)) else "",
            int(offer.get("price", 0))
        ])
        fighter_list.set_item_metadata(index, str(offer.get("id", "")))

    if offers.is_empty():
        selected_fighter_offer_id = ""
        fighter_details.text = "[b]NO HAY OFERTAS DISPONIBLES[/b]\n\nEl mercado general volverá a renovarse en la semana %d." % MarketManager.get_next_auto_refresh_week()
        fighter_buy_button.disabled = true
        return

    var selected_index := 0
    for index in range(offers.size()):
        if str(offers[index].get("id", "")) == previous_id:
            selected_index = index
            break
    selected_fighter_offer_id = str(offers[selected_index].get("id", ""))
    fighter_list.select(selected_index)
    _refresh_fighter_details()

func _on_fighter_selected(index: int) -> void:
    if index < 0 or index >= fighter_list.item_count:
        return
    selected_fighter_offer_id = str(fighter_list.get_item_metadata(index))
    _refresh_fighter_details()

func _refresh_fighter_details() -> void:
    var offer := MarketManager.get_offer(selected_fighter_offer_id)
    if offer.is_empty():
        fighter_details.text = "Seleccioná una oferta de luchador."
        fighter_buy_button.disabled = true
        return
    var traits: Array[String] = []
    for raw_trait in offer.get("traits", []):
        traits.append(str(raw_trait).replace("_", " ").capitalize())
    fighter_details.text = "[b]%s[/b]%s\n%s de %s\n\nFuerza %d · Agilidad %d\nResistencia %d · Técnica %d\nInteligencia %d · Salud %d\nLealtad %d\n\nRasgos: %s\n\n[b]PRECIO: %d DENARIOS[/b]" % [
        offer.get("name", "Sin nombre"),
        "\n[color=gold][b]GLADIADOR ÚNICO[/b][/color]" if bool(offer.get("unique", false)) else "",
        _role_label(str(offer.get("role", "slave"))),
        offer.get("origin", "Origen desconocido"),
        int(offer.get("strength", 0)), int(offer.get("agility", 0)), int(offer.get("endurance", 0)),
        int(offer.get("technique", 0)), int(offer.get("intelligence", 0)), int(offer.get("health", 0)),
        int(offer.get("loyalty", 0)), ", ".join(traits) if not traits.is_empty() else "Ninguno",
        int(offer.get("price", 0))
    ]
    fighter_buy_button.text = "COMPRAR A %s · %d" % [offer.get("name", "LUCHADOR"), int(offer.get("price", 0))]
    fighter_buy_button.disabled = CampaignManager.campaign_over or GameState.denarii < int(offer.get("price", 0)) or not RosterManager.has_capacity()

func _buy_selected_fighter() -> void:
    if selected_fighter_offer_id.is_empty():
        feedback.text = "Seleccioná un luchador antes de comprar."
        return
    MarketManager.buy_offer(selected_fighter_offer_id)

func _refresh_equipment_offers() -> void:
    var previous_id := selected_equipment_offer_id
    equipment_list.clear()
    var offers := MarketManager.get_equipment_offers()
    for index in range(offers.size()):
        var offer: Dictionary = offers[index]
        var slot_id := _offer_slot(offer)
        equipment_list.add_item("%s · %s · %s · %d denarios" % [
            offer.get("name", "Objeto"), EquipmentManager.get_slot_label(slot_id),
            offer.get("quality", "Común"), int(offer.get("price", 0))
        ])
        equipment_list.set_item_metadata(index, str(offer.get("id", "")))

    if offers.is_empty():
        selected_equipment_offer_id = ""
        equipment_details.text = "[b]SIN EQUIPAMIENTO DISPONIBLE[/b]\n\nPodés esperar la renovación general o renovar esta sección por 100 denarios."
        equipment_buy_button.disabled = true
        _refresh_controls()
        return

    var selected_index := 0
    for index in range(offers.size()):
        if str(offers[index].get("id", "")) == previous_id:
            selected_index = index
            break
    selected_equipment_offer_id = str(offers[selected_index].get("id", ""))
    equipment_list.select(selected_index)
    _refresh_equipment_details()
    _refresh_controls()

func _on_equipment_selected(index: int) -> void:
    if index < 0 or index >= equipment_list.item_count:
        return
    selected_equipment_offer_id = str(equipment_list.get_item_metadata(index))
    _refresh_equipment_details()

func _refresh_equipment_details() -> void:
    var offer := MarketManager.get_equipment_offer(selected_equipment_offer_id)
    if offer.is_empty():
        equipment_details.text = "Seleccioná una oferta de equipamiento."
        equipment_buy_button.disabled = true
        return
    var stat_lines: Array[String] = []
    if int(offer.get("power", 0)) > 0:
        stat_lines.append("Ataque base: +%d" % int(offer.get("power", 0)))
    if int(offer.get("defense", 0)) > 0:
        stat_lines.append("Defensa base: +%d" % int(offer.get("defense", 0)))
    var tags: Array[String] = []
    for raw_tag in offer.get("tags", []):
        tags.append(str(raw_tag).replace("_", " ").capitalize())
    var slot_id := _offer_slot(offer)
    equipment_details.text = "[b]%s[/b]\n%s · Ranura: %s · Calidad %s\n\n%s\n\nEtiquetas: %s\n\nAl comprarlo se guardará en el inventario del ludus y aparecerá en la pestaña Equipamiento de cada ficha compatible.\n\n[b]PRECIO: %d DENARIOS[/b]" % [
        offer.get("name", "Objeto"), _equipment_type_label(str(offer.get("type", "weapon"))),
        EquipmentManager.get_slot_label(slot_id), offer.get("quality", "Común"),
        "\n".join(stat_lines) if not stat_lines.is_empty() else "Sin bonificación de combate.",
        ", ".join(tags) if not tags.is_empty() else "Ninguna", int(offer.get("price", 0))
    ]
    equipment_buy_button.text = "COMPRAR %s · %d" % [offer.get("name", "EQUIPAMIENTO"), int(offer.get("price", 0))]
    equipment_buy_button.disabled = CampaignManager.campaign_over or GameState.denarii < int(offer.get("price", 0))

func _offer_slot(offer: Dictionary) -> String:
    var slot_id := EquipmentManager.canonical_slot_id(str(offer.get("slot", "")))
    return slot_id if not slot_id.is_empty() else EquipmentManager.get_item_slot(offer)

func _buy_selected_equipment() -> void:
    if selected_equipment_offer_id.is_empty():
        feedback.text = "Seleccioná un objeto antes de comprar."
        return
    MarketManager.buy_equipment_offer(selected_equipment_offer_id)

func _refresh_equipment_only() -> void:
    MarketManager.refresh_equipment_market(true)

func _refresh_controls() -> void:
    equipment_refresh_button.text = "RENOVAR EQUIPAMIENTO · %d" % MarketManager.EQUIPMENT_REFRESH_COST
    equipment_refresh_button.disabled = CampaignManager.campaign_over or GameState.denarii < MarketManager.EQUIPMENT_REFRESH_COST
    if not selected_fighter_offer_id.is_empty():
        _refresh_fighter_details()
    if not selected_equipment_offer_id.is_empty():
        _refresh_equipment_details()

func _on_fighter_purchase_completed(person_name: String, price: int) -> void:
    feedback.text = "%s se incorporó al ludus por %d denarios." % [person_name, price]
    selected_fighter_offer_id = ""
    _refresh_fighter_offers()
    if active_section == "fighters":
        content_shell.visible = true
        fighters_view.visible = true

func _on_fighter_purchase_failed(reason: String) -> void:
    feedback.text = reason
    _refresh_controls()

func _on_equipment_purchase_completed(item_name: String, price: int) -> void:
    feedback.text = "%s fue enviado al inventario por %d denarios." % [item_name, price]
    selected_equipment_offer_id = ""
    _refresh_equipment_offers()
    if active_section == "equipment":
        content_shell.visible = true
        equipment_view.visible = true

func _on_equipment_purchase_failed(reason: String) -> void:
    feedback.text = reason
    _refresh_controls()

func _role_label(role: String) -> String:
    return "Gladiador" if role == "gladiator" else "Esclavo en formación"

func _equipment_type_label(item_type: String) -> String:
    match item_type:
        "weapon": return "Arma"
        "armor": return "Armadura de torso"
        "shield": return "Escudo"
        "helmet", "head": return "Casco"
        "lower_body", "boots", "greaves": return "Protección inferior"
        "accessory", "antidote", "cheat_item": return "Accesorio"
        "mount": return "Montura"
        _: return item_type.replace("_", " ").capitalize()

func _return_to_finca() -> void:
    FincaHubController.show_finca()
