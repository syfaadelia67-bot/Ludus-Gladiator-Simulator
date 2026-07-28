extends Control

@onready var resources_label: Label = $Margin/VBox/Resources
@onready var advance_button: Button = $Margin/VBox/TopButtons/AdvanceDay
@onready var refresh_market_button: Button = $Margin/VBox/TopButtons/RefreshMarket
@onready var capacity_label: Label = $Margin/VBox/TopButtons/Capacity
@onready var roster_list: ItemList = $Margin/VBox/Columns/RosterPanel/RosterList
@onready var details: RichTextLabel = $Margin/VBox/Columns/RosterPanel/Details
@onready var job_selector: OptionButton = $Margin/VBox/Columns/RosterPanel/JobRow/JobSelector
@onready var assign_button: Button = $Margin/VBox/Columns/RosterPanel/JobRow/AssignJob
@onready var market_list: ItemList = $Margin/VBox/Columns/RightPanel/MarketList
@onready var market_details: RichTextLabel = $Margin/VBox/Columns/RightPanel/MarketDetails
@onready var buy_button: Button = $Margin/VBox/Columns/RightPanel/BuyOffer
@onready var log: RichTextLabel = $Margin/VBox/Columns/RightPanel/Log

var selected_person_id: String = ""
var selected_offer_id: String = ""
var job_ids: Array[String] = []

func _ready() -> void:
    advance_button.pressed.connect(_on_advance_day)
    refresh_market_button.pressed.connect(_on_refresh_market)
    roster_list.item_selected.connect(_on_person_selected)
    market_list.item_selected.connect(_on_offer_selected)
    assign_button.pressed.connect(_on_assign_job)
    buy_button.pressed.connect(_on_buy_offer)
    GameState.resources_changed.connect(_refresh_resources)
    GameState.day_advanced.connect(_on_day_advanced)
    GameState.daily_report.connect(_on_daily_report)
    RosterManager.roster_changed.connect(_refresh_roster)
    MarketManager.market_changed.connect(_refresh_market)
    MarketManager.purchase_completed.connect(_on_purchase_completed)
    MarketManager.purchase_failed.connect(_on_purchase_failed)
    _populate_jobs()
    _refresh_resources()
    _refresh_roster()
    _refresh_market()

func _populate_jobs() -> void:
    job_selector.clear()
    job_ids = RosterManager.get_job_ids()
    for job_id in job_ids:
        job_selector.add_item(RosterManager.get_job_name(job_id))

func _on_advance_day() -> void:
    GameState.advance_day()

func _on_refresh_market() -> void:
    MarketManager.refresh_market(true)

func _on_person_selected(index: int) -> void:
    selected_person_id = str(roster_list.get_item_metadata(index))
    _refresh_details()

func _on_offer_selected(index: int) -> void:
    selected_offer_id = str(market_list.get_item_metadata(index))
    _refresh_market_details()

func _on_assign_job() -> void:
    if selected_person_id.is_empty() or job_selector.selected < 0:
        log.append_text("\n[color=orange]Seleccioná un personaje y un trabajo.[/color]")
        return
    var job_id := job_ids[job_selector.selected]
    if RosterManager.assign_job(selected_person_id, job_id):
        var person = RosterManager.get_person(selected_person_id)
        log.append_text("\n%s fue asignado a %s." % [person.display_name, RosterManager.get_job_name(job_id)])
        _refresh_details()

func _on_buy_offer() -> void:
    if selected_offer_id.is_empty():
        log.append_text("\n[color=orange]Seleccioná una oferta del mercado.[/color]")
        return
    MarketManager.buy_offer(selected_offer_id)

func _on_purchase_completed(person_name: String, price: int) -> void:
    log.append_text("\n[color=gold]Compraste a %s por %d denarios.[/color]" % [person_name, price])
    selected_offer_id = ""
    _refresh_resources()

func _on_purchase_failed(reason: String) -> void:
    log.append_text("\n[color=orange]%s[/color]" % reason)

func _on_day_advanced(day: int) -> void:
    log.append_text("\n\n[b]Día %d[/b]" % day)

func _on_daily_report(report: Dictionary) -> void:
    log.append_text("\nMineral producido: %d" % int(report.get("ore", 0)))
    log.append_text("\nSeguridad generada: %d" % int(report.get("security", 0)))
    log.append_text("\nInformación obtenida: %d" % int(report.get("intel", 0)))
    log.append_text("\nEntrenamiento total: %d" % int(report.get("training", 0)))
    for person_name in report.get("promotions", []):
        log.append_text("\n[color=gold]%s completó su formación y ahora es gladiador.[/color]" % person_name)

func _refresh_resources() -> void:
    resources_label.text = GameState.get_resource_summary()
    capacity_label.text = "Capacidad: %s" % RosterManager.get_capacity_summary()

func _refresh_roster() -> void:
    roster_list.clear()
    var selected_index := -1
    var people := RosterManager.get_people()
    for index in range(people.size()):
        var person = people[index]
        roster_list.add_item("%s — %s — %s" % [person.display_name, _role_name(person.role), RosterManager.get_job_name(person.job)])
        roster_list.set_item_metadata(index, person.id)
        if person.id == selected_person_id:
            selected_index = index
    if selected_index >= 0:
        roster_list.select(selected_index)
    elif not people.is_empty():
        selected_person_id = people[0].id
        roster_list.select(0)
    _refresh_details()
    _refresh_resources()

func _refresh_details() -> void:
    var person = RosterManager.get_person(selected_person_id)
    if person == null:
        details.text = "Seleccioná un personaje."
        assign_button.disabled = true
        return
    assign_button.disabled = false
    var trait_text := ", ".join(person.traits) if not person.traits.is_empty() else "Ninguno"
    details.text = "[b]%s[/b]\nOrigen: %s | Rol: %s\nFuerza: %d | Agilidad: %d | Resistencia: %d | Inteligencia: %d\nLealtad: %d | Moral: %d | Fatiga: %d\nEntrenamiento: %d/100\nRasgos: %s" % [person.display_name, person.origin, _role_name(person.role), person.strength, person.agility, person.endurance, person.intelligence, person.loyalty, person.morale, person.fatigue, person.training, trait_text]
    var current_job_index := job_ids.find(person.job)
    if current_job_index >= 0:
        job_selector.select(current_job_index)

func _refresh_market() -> void:
    market_list.clear()
    var offers := MarketManager.get_offers()
    for index in range(offers.size()):
        var offer: Dictionary = offers[index]
        market_list.add_item("%s — %s — %d denarios" % [offer.get("name", "?"), _role_name(str(offer.get("role", "slave"))), int(offer.get("price", 0))])
        market_list.set_item_metadata(index, str(offer.get("id", "")))
    if offers.is_empty():
        selected_offer_id = ""
        market_details.text = "No hay ofertas disponibles."
        buy_button.disabled = true
    else:
        if MarketManager.get_offer(selected_offer_id).is_empty():
            selected_offer_id = str(offers[0].get("id", ""))
        market_list.select(0)
        buy_button.disabled = false
        _refresh_market_details()

func _refresh_market_details() -> void:
    var offer := MarketManager.get_offer(selected_offer_id)
    if offer.is_empty():
        market_details.text = "Seleccioná una oferta."
        buy_button.disabled = true
        return
    buy_button.disabled = false
    market_details.text = "[b]%s[/b] — %s de %s\nFuerza: %d | Agilidad: %d | Resistencia: %d | Inteligencia: %d\nLealtad: %d | Rasgo: %s | Precio: %d" % [offer.get("name", "?"), _role_name(str(offer.get("role", "slave"))), offer.get("origin", "?"), int(offer.get("strength", 0)), int(offer.get("agility", 0)), int(offer.get("endurance", 0)), int(offer.get("intelligence", 0)), int(offer.get("loyalty", 0)), ", ".join(offer.get("traits", [])), int(offer.get("price", 0))]

func _role_name(role_id: String) -> String:
    match role_id:
        "slave": return "Esclavo"
        "gladiator": return "Gladiador"
        _: return role_id.capitalize()
