extends VBoxContainer

@onready var back_button: Button = $Header/BackToFinca
@onready var rotation_label: Label = $Header/Rotation
@onready var fighters_button: Button = $ModeButtons/Fighters
@onready var equipment_button: Button = $ModeButtons/Equipment
@onready var feedback: Label = $Feedback

@onready var fighters_view: HSplitContainer = $FightersView
@onready var fighter_list: ItemList = $FightersView/OffersPanel/Margin/Content/List
@onready var fighter_details: RichTextLabel = $FightersView/DetailsPanel/Margin/Scroll/Content/Details
@onready var fighter_buy_button: Button = $FightersView/DetailsPanel/Margin/Scroll/Content/Buy

@onready var equipment_view: HSplitContainer = $EquipmentView
@onready var equipment_list: ItemList = $EquipmentView/OffersPanel/Margin/Content/List
@onready var equipment_refresh_button: Button = $EquipmentView/OffersPanel/Margin/Content/Header/Refresh
@onready var equipment_details: RichTextLabel = $EquipmentView/DetailsPanel/Margin/Scroll/Content/Details
@onready var equipment_buy_button: Button = $EquipmentView/DetailsPanel/Margin/Scroll/Content/Buy

var selected_fighter_offer_id := ""
var selected_equipment_offer_id := ""

func _ready() -> void:
    back_button.pressed.connect(_return_to_finca)
    fighters_button.pressed.connect(_show_fighters)
    equipment_button.pressed.connect(_show_equipment)
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

    _show_fighters()
    _refresh_all()

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        _return_to_finca()
        get_viewport().set_input_as_handled()

func _on_visibility_changed() -> void:
    if is_visible_in_tree():
        _refresh_all()

func _show_fighters() -> void:
    fighters_view.visible = true
    fighters_view.mouse_filter = Control.MOUSE_FILTER_PASS
    equipment_view.visible = false
    equipment_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fighters_button.disabled = true
    equipment_button.disabled = false
    feedback.text = "Ofertas de luchadores. La renovación de esta sección es automática."

func _show_equipment() -> void:
    fighters_view.visible = false
    fighters_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    equipment_view.visible = true
    equipment_view.mouse_filter = Control.MOUSE_FILTER_PASS
    fighters_button.disabled = false
    equipment_button.disabled = true
    feedback.text = "Equipamiento del mercado. Podés renovar solo esta sección por 100 denarios."

func _refresh_all() -> void:
    _refresh_rotation_label()
    _refresh_fighter_offers()
    _refresh_equipment_offers()
    _refresh_controls()

func _refresh_rotation_label() -> void:
    var weeks_left := MarketManager.get_weeks_until_auto_refresh()
    rotation_label.text = "RENOVACIÓN GENERAL · SEMANA %d\nFALTAN %d SEMANA(S)" % [
        MarketManager.get_next_auto_refresh_week(),
        weeks_left
    ]

func _refresh_fighter_offers() -> void:
    var previous_id := selected_fighter_offer_id
    fighter_list.clear()
    var offers := MarketManager.get_offers()
    for index in range(offers.size()):
        var offer: Dictionary = offers[index]
        var role_text := _role_label(str(offer.get("role", "slave")))
        var unique_text := " · ÚNICO" if bool(offer.get("unique", false)) else ""
        fighter_list.add_item("%s · %s%s · %d denarios" % [
            offer.get("name", "Sin nombre"),
            role_text,
            unique_text,
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
    var unique_line := "\n[color=gold][b]GLADIADOR ÚNICO[/b][/color]" if bool(offer.get("unique", false)) else ""
    fighter_details.text = "[b]%s[/b]%s\n%s de %s\n\nFuerza %d · Agilidad %d\nResistencia %d · Técnica %d\nInteligencia %d · Salud %d\nLealtad %d\n\nRasgos: %s\n\n[b]PRECIO: %d DENARIOS[/b]" % [
        offer.get("name", "Sin nombre"),
        unique_line,
        _role_label(str(offer.get("role", "slave"))),
        offer.get("origin", "Origen desconocido"),
        int(offer.get("strength", 0)),
        int(offer.get("agility", 0)),
        int(offer.get("endurance", 0)),
        int(offer.get("technique", 0)),
        int(offer.get("intelligence", 0)),
        int(offer.get("health", 0)),
        int(offer.get("loyalty", 0)),
        ", ".join(traits) if not traits.is_empty() else "Ninguno",
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
        equipment_list.add_item("%s · %s · %s · %d denarios" % [
            offer.get("name", "Objeto"),
            _equipment_type_label(str(offer.get("type", "weapon"))),
            offer.get("quality", "Común"),
            int(offer.get("price", 0))
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
    equipment_details.text = "[b]%s[/b]\n%s · Calidad %s\n\n%s\n\nEtiquetas: %s\n\nAl comprarlo se guardará en el inventario del ludus.\n\n[b]PRECIO: %d DENARIOS[/b]" % [
        offer.get("name", "Objeto"),
        _equipment_type_label(str(offer.get("type", "weapon"))),
        offer.get("quality", "Común"),
        "\n".join(stat_lines) if not stat_lines.is_empty() else "Sin bonificación de combate.",
        ", ".join(tags) if not tags.is_empty() else "Ninguna",
        int(offer.get("price", 0))
    ]
    equipment_buy_button.text = "COMPRAR %s · %d" % [offer.get("name", "EQUIPAMIENTO"), int(offer.get("price", 0))]
    equipment_buy_button.disabled = CampaignManager.campaign_over or GameState.denarii < int(offer.get("price", 0))

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

func _on_fighter_purchase_failed(reason: String) -> void:
    feedback.text = reason
    _refresh_controls()

func _on_equipment_purchase_completed(item_name: String, price: int) -> void:
    feedback.text = "%s fue enviado al inventario por %d denarios." % [item_name, price]
    selected_equipment_offer_id = ""
    _refresh_equipment_offers()

func _on_equipment_purchase_failed(reason: String) -> void:
    feedback.text = reason
    _refresh_controls()

func _role_label(role: String) -> String:
    return "Gladiador" if role == "gladiator" else "Esclavo en formación"

func _equipment_type_label(item_type: String) -> String:
    match item_type:
        "weapon": return "Arma"
        "armor": return "Armadura"
        "shield": return "Escudo"
        _: return item_type.capitalize()

func _return_to_finca() -> void:
    FincaHubController.show_finca()
