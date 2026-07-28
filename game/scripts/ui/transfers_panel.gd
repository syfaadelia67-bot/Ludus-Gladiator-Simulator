extends Control

@onready var person_select: OptionButton = %PersonSelect
@onready var person_details: RichTextLabel = %PersonDetails
@onready var rival_list: ItemList = %RivalList
@onready var rival_details: RichTextLabel = %RivalDetails
@onready var history_label: RichTextLabel = %HistoryLabel
@onready var status_label: Label = %StatusLabel
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog

var person_ids: Array[String] = []
var rival_ids: Array[String] = []
var pending_action: String = ""
var pending_id: String = ""

func _ready() -> void:
    person_select.item_selected.connect(func(_index): _refresh_person_details())
    rival_list.item_selected.connect(func(_index): _refresh_rival_details())
    %SellButton.pressed.connect(func(): _request_confirmation("sell", _selected_person_id(), "¿Vender a esta persona?"))
    %NegotiateButton.pressed.connect(func(): _request_confirmation("negotiate", _selected_person_id(), "¿Intentar negociar la venta usando 6 puntos de inteligencia?"))
    %ManumitButton.pressed.connect(func(): _request_confirmation("manumit", _selected_person_id(), "¿Conceder la libertad? Esta decisión es irreversible."))
    %RansomButton.pressed.connect(func(): _request_confirmation("ransom", _selected_person_id(), "¿Pagar el rescate para asegurar su permanencia?"))
    %BuyRivalButton.pressed.connect(func(): _request_confirmation("buy", _selected_rival_id(), "¿Comprar este gladiador rival?"))
    %RefreshOffersButton.pressed.connect(_refresh_rival_offers)
    %RefreshOffersButton.text = "Renovar ofertas (%d denarios)" % TransferManager.OFFER_REFRESH_COST
    confirm_dialog.confirmed.connect(_execute_pending_action)
    TransferManager.transfers_changed.connect(_refresh)
    RosterManager.roster_changed.connect(_refresh)
    GameState.resources_changed.connect(_refresh)
    _refresh()

func _refresh() -> void:
    _refresh_people()
    _refresh_rivals()
    _refresh_history()

func _refresh_people() -> void:
    var previous := _selected_person_id()
    person_ids.clear()
    person_select.clear()
    for person in RosterManager.get_people():
        person_ids.append(person.id)
        person_select.add_item("%s — %s" % [person.display_name, person.role])
    var index := person_ids.find(previous)
    if index < 0 and not person_ids.is_empty():
        index = 0
    if index >= 0:
        person_select.select(index)
    _refresh_person_details()

func _refresh_person_details() -> void:
    var person_id := _selected_person_id()
    var person = RosterManager.get_person(person_id)
    if person == null:
        person_details.text = "No hay personas disponibles."
        return
    var value := TransferManager.get_person_value(person_id)
    var sale_value := int(round(value * 0.72))
    var negotiated_value := int(round(value * 0.90))
    var ransom := maxi(80, int(round(value * 0.35)))
    var relation_notes: Array[String] = []
    for relation in RelationshipManager.get_person_relationships(person_id):
        var other_id := str(relation.get("b_id", "")) if str(relation.get("a_id", "")) == person_id else str(relation.get("a_id", ""))
        var other = RosterManager.get_person(other_id)
        if other != null and str(relation.get("state", "neutral")) != "neutral":
            relation_notes.append("%s: %s" % [other.display_name, relation.get("state", "neutral")])
    person_details.text = "[b]%s[/b]\nRol: %s | Origen: %s\nValor estimado: %d\nVenta directa: %d\nVenta negociada potencial: %d\nRescate estimado: %d\nInteligencia disponible: %d\nReputación actual: %d\nConsecuencias sociales: %s" % [
        person.display_name, person.role, person.origin, value, sale_value, negotiated_value, ransom,
        RosterManager.intelligence_points, GameState.reputation,
        ", ".join(relation_notes) if not relation_notes.is_empty() else "sin vínculos destacados"
    ]
    %SellButton.disabled = person.role == "freed" or RosterManager.people.size() <= 1
    %NegotiateButton.disabled = person.role == "freed" or RosterManager.people.size() <= 1 or RosterManager.intelligence_points < 6
    %RansomButton.disabled = person.role == "freed"
    %ManumitButton.disabled = person.role == "freed"

func _refresh_rivals() -> void:
    var previous := _selected_rival_id()
    rival_ids.clear()
    rival_list.clear()
    for offer in TransferManager.get_rival_offers():
        rival_ids.append(str(offer.get("id", "")))
        rival_list.add_item("%s — %d denarios" % [offer.get("name", "Sin nombre"), int(offer.get("price", 0))])
    var index := rival_ids.find(previous)
    if index < 0 and not rival_ids.is_empty():
        index = 0
    if index >= 0:
        rival_list.select(index)
    _refresh_rival_details()

func _refresh_rival_details() -> void:
    var offer_id := _selected_rival_id()
    var offer: Dictionary = {}
    for candidate in TransferManager.get_rival_offers():
        if str(candidate.get("id", "")) == offer_id:
            offer = candidate
            break
    if offer.is_empty():
        rival_details.text = "No hay ofertas rivales disponibles."
        %BuyRivalButton.disabled = true
        return
    var traits: Array[String] = []
    for trait_id in offer.get("traits", []):
        traits.append(PersonalityManager.get_trait_name(str(trait_id)))
    rival_details.text = "[b]%s[/b]\nVendedor: %s | Origen: %s\nFuerza %d | Agilidad %d | Resistencia %d | Inteligencia %d\nLealtad inicial: %d\nRasgos: %s\nPrecio: %d denarios" % [
        offer.get("name", ""), offer.get("seller", ""), offer.get("origin", ""),
        int(offer.get("strength", 0)), int(offer.get("agility", 0)), int(offer.get("endurance", 0)), int(offer.get("intelligence", 0)),
        int(offer.get("loyalty", 0)), ", ".join(traits), int(offer.get("price", 0))
    ]
    %BuyRivalButton.disabled = not RosterManager.has_capacity() or GameState.denarii < int(offer.get("price", 0))

func _refresh_history() -> void:
    var lines: Array[String] = []
    for entry in TransferManager.history.slice(0, 14):
        lines.append("Día %d — %s" % [int(entry.get("day", 0)), str(entry.get("description", "Movimiento registrado"))])
    history_label.text = "\n".join(lines) if not lines.is_empty() else "Todavía no hay transferencias registradas."

func _request_confirmation(action: String, target_id: String, text: String) -> void:
    if target_id.is_empty():
        status_label.text = "No hay una selección válida."
        return
    pending_action = action
    pending_id = target_id
    confirm_dialog.dialog_text = text
    confirm_dialog.popup_centered()

func _execute_pending_action() -> void:
    var result: Dictionary = {}
    match pending_action:
        "sell": result = TransferManager.sell_person(pending_id)
        "negotiate": result = TransferManager.negotiate_sale(pending_id)
        "manumit": result = TransferManager.manumit(pending_id)
        "ransom": result = TransferManager.pay_ransom(pending_id)
        "buy": result = TransferManager.buy_rival_offer(pending_id)
    status_label.text = str(result.get("description", result.get("error", "La operación no pudo completarse.")))
    pending_action = ""
    pending_id = ""
    _refresh()

func _refresh_rival_offers() -> void:
    if TransferManager.generate_rival_offers(true):
        status_label.text = "Las ofertas rivales fueron actualizadas."
    else:
        status_label.text = "No hay fondos para renovar las ofertas rivales."

func _selected_person_id() -> String:
    var index := person_select.selected
    return person_ids[index] if index >= 0 and index < person_ids.size() else ""

func _selected_rival_id() -> String:
    var selected := rival_list.get_selected_items()
    if selected.is_empty():
        return rival_ids[0] if not rival_ids.is_empty() else ""
    var index := int(selected[0])
    return rival_ids[index] if index >= 0 and index < rival_ids.size() else ""
