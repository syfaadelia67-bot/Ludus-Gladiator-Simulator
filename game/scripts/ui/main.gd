extends Control

@onready var resources_label: Label = $Margin/VBox/Resources
@onready var advance_button: Button = $Margin/VBox/TopButtons/AdvanceDay
@onready var refresh_market_button: Button = $Margin/VBox/TopButtons/RefreshMarket
@onready var capacity_label: Label = $Margin/VBox/TopButtons/Capacity
@onready var market_list: ItemList = $Margin/VBox/Tabs/Mercado/MarketList
@onready var market_details: RichTextLabel = $Margin/VBox/Tabs/Mercado/MarketDetails
@onready var buy_button: Button = $Margin/VBox/Tabs/Mercado/BuyOffer
@onready var building_list: ItemList = $Margin/VBox/Tabs/Finca/BuildingList
@onready var building_details: RichTextLabel = $Margin/VBox/Tabs/Finca/BuildingPanel/BuildingDetails
@onready var upgrade_button: Button = $Margin/VBox/Tabs/Finca/BuildingPanel/UpgradeBuilding
@onready var gladiator_selector: OptionButton = $Margin/VBox/Tabs/Arena/Setup/GladiatorSelector
@onready var tactic_selector: OptionButton = $Margin/VBox/Tabs/Arena/Setup/TacticSelector
@onready var start_duel_button: Button = $Margin/VBox/Tabs/Arena/Setup/StartDuel
@onready var player_name: Label = $Margin/VBox/Tabs/Arena/Stage/PlayerCard/Name
@onready var player_health: ProgressBar = $Margin/VBox/Tabs/Arena/Stage/PlayerCard/Health
@onready var player_energy: ProgressBar = $Margin/VBox/Tabs/Arena/Stage/PlayerCard/Energy
@onready var enemy_name: Label = $Margin/VBox/Tabs/Arena/Stage/EnemyCard/Name
@onready var enemy_health: ProgressBar = $Margin/VBox/Tabs/Arena/Stage/EnemyCard/Health
@onready var enemy_energy: ProgressBar = $Margin/VBox/Tabs/Arena/Stage/EnemyCard/Energy
@onready var arena_result: Label = $Margin/VBox/Tabs/Arena/Result
@onready var combat_log: RichTextLabel = $Margin/VBox/Tabs/Arena/CombatLog

var selected_offer_id := ""
var selected_building_id := ""
var gladiator_ids: Array[String] = []
var tactic_ids: Array[String] = []

func _ready() -> void:
    advance_button.pressed.connect(_on_advance_week)
    refresh_market_button.pressed.connect(_on_refresh_market)
    market_list.item_selected.connect(_on_offer_selected)
    building_list.item_selected.connect(_on_building_selected)
    buy_button.pressed.connect(_on_buy_offer)
    upgrade_button.pressed.connect(_on_upgrade_building)
    start_duel_button.pressed.connect(_on_start_duel)
    GameState.resources_changed.connect(_refresh_resources)
    RosterManager.roster_changed.connect(_on_roster_changed)
    MarketManager.market_changed.connect(_refresh_market)
    MarketManager.purchase_completed.connect(_on_purchase_completed)
    MarketManager.purchase_failed.connect(_on_action_failed)
    EstateManager.estate_changed.connect(_refresh_estate)
    EstateManager.upgrade_completed.connect(_on_upgrade_completed)
    EstateManager.upgrade_failed.connect(_on_action_failed)
    CombatManager.combat_finished.connect(_on_combat_finished)
    CombatManager.combat_failed.connect(_on_action_failed)
    _populate_tactics()
    _refresh_resources()
    _refresh_market()
    _refresh_estate()
    _refresh_gladiators()

func _populate_tactics() -> void:
    tactic_selector.clear()
    tactic_ids = CombatManager.get_tactic_ids()
    for tactic_id in tactic_ids:
        tactic_selector.add_item(CombatManager.get_tactic_name(tactic_id))

func _on_advance_week() -> void:
    GameState.advance_week()

func _on_refresh_market() -> void:
    MarketManager.refresh_market(true)

func _on_offer_selected(index: int) -> void:
    selected_offer_id = str(market_list.get_item_metadata(index))
    _refresh_market_details()

func _on_building_selected(index: int) -> void:
    selected_building_id = str(building_list.get_item_metadata(index))
    _refresh_building_details()

func _on_buy_offer() -> void:
    if selected_offer_id.is_empty():
        _on_action_failed("Seleccioná una oferta del mercado.")
        return
    MarketManager.buy_offer(selected_offer_id)

func _on_upgrade_building() -> void:
    if selected_building_id.is_empty():
        _on_action_failed("Seleccioná una instalación.")
        return
    EstateManager.upgrade(selected_building_id)

func _on_start_duel() -> void:
    if gladiator_selector.selected < 0 or gladiator_ids.is_empty():
        arena_result.text = "No hay gladiadores disponibles."
        return
    var fighter_id := gladiator_ids[gladiator_selector.selected]
    var tactic_id := tactic_ids[tactic_selector.selected] if tactic_selector.selected >= 0 else "balanced"
    start_duel_button.disabled = true
    arena_result.text = "El combate semanal está comenzando..."
    CombatManager.simulate_duel(fighter_id, tactic_id)
    start_duel_button.disabled = false

func _on_purchase_completed(_person_name_value: String, _price: int) -> void:
    selected_offer_id = ""

func _on_upgrade_completed(_building_id: String, _new_level: int) -> void:
    _refresh_estate()

func _on_combat_finished(result: Dictionary) -> void:
    player_name.text = str(result.get("fighter", "Gladiador"))
    enemy_name.text = str(result.get("enemy", "Rival"))
    _set_bar(player_health, int(result.get("player_health", 0)), int(result.get("player_max_health", 1)))
    _set_bar(player_energy, int(result.get("player_energy", 0)), int(result.get("player_max_energy", 1)))
    _set_bar(enemy_health, int(result.get("enemy_health", 0)), int(result.get("enemy_max_health", 1)))
    _set_bar(enemy_energy, int(result.get("enemy_energy", 0)), int(result.get("enemy_max_energy", 1)))
    var victory := bool(result.get("victory", false))
    if victory:
        arena_result.text = "VICTORIA — %d denarios y %d reputación" % [int(result.get("reward", 0)), int(result.get("reputation", 0))]
    else:
        arena_result.text = "DERROTA — el gladiador necesita recuperarse"
    combat_log.clear()
    combat_log.append_text("[b]Crónica de la arena[/b]\n")
    for entry in result.get("log", []):
        combat_log.append_text("%s\n" % str(entry))

func _set_bar(bar: ProgressBar, value: int, maximum: int) -> void:
    bar.max_value = maxi(1, maximum)
    bar.value = clampi(value, 0, maximum)
    bar.tooltip_text = "%d/%d" % [value, maximum]

func _on_action_failed(reason: String) -> void:
    arena_result.text = reason

func _on_roster_changed() -> void:
    _refresh_resources()
    _refresh_gladiators()

func _refresh_resources() -> void:
    resources_label.text = GameState.get_resource_summary()
    capacity_label.text = "Capacidad: %s" % RosterManager.get_capacity_summary()

func _refresh_gladiators() -> void:
    var previous_id := ""
    if gladiator_selector.selected >= 0 and gladiator_selector.selected < gladiator_ids.size():
        previous_id = gladiator_ids[gladiator_selector.selected]
    gladiator_selector.clear()
    gladiator_ids.clear()
    for person in RosterManager.get_people():
        if person.role == "gladiator":
            gladiator_ids.append(person.id)
            gladiator_selector.add_item("%s — ATQ %d / DEF %d" % [person.display_name, person.get_base_attack(), person.get_base_defense()])
    if gladiator_ids.is_empty():
        start_duel_button.disabled = true
        arena_result.text = "Entrená o comprá un gladiador para competir."
        return
    start_duel_button.disabled = false
    var selected_index := gladiator_ids.find(previous_id)
    gladiator_selector.select(selected_index if selected_index >= 0 else 0)

func _refresh_market() -> void:
    market_list.clear()
    var offers := MarketManager.get_offers()
    for index in range(offers.size()):
        var offer: Dictionary = offers[index]
        market_list.add_item("%s — %s — %d denarios" % [offer.get("name", "?"), _role_name(str(offer.get("role", "slave"))), int(offer.get("price", 0))])
        market_list.set_item_metadata(index, str(offer.get("id", "")))
    if offers.is_empty():
        selected_offer_id = ""
    elif MarketManager.get_offer(selected_offer_id).is_empty():
        selected_offer_id = str(offers[0].get("id", ""))
        market_list.select(0)
    _refresh_market_details()

func _refresh_market_details() -> void:
    var offer := MarketManager.get_offer(selected_offer_id)
    if offer.is_empty():
        market_details.text = "No hay oferta seleccionada."
        buy_button.disabled = true
        return
    buy_button.disabled = false
    market_details.text = "[b]%s[/b] — %s de %s\nFuerza: %d | Agilidad: %d | Resistencia: %d | Inteligencia: %d\nLealtad: %d | Rasgo: %s | Precio: %d" % [offer.get("name", "?"), _role_name(str(offer.get("role", "slave"))), offer.get("origin", "?"), int(offer.get("strength", 0)), int(offer.get("agility", 0)), int(offer.get("endurance", 0)), int(offer.get("intelligence", 0)), int(offer.get("loyalty", 0)), ", ".join(offer.get("traits", [])), int(offer.get("price", 0))]

func _refresh_estate() -> void:
    building_list.clear()
    var ids := EstateManager.get_building_ids()
    for index in range(ids.size()):
        var data := EstateManager.get_building_data(ids[index])
        building_list.add_item("%s — Nivel %d" % [data.get("name", ids[index]), int(data.get("level", 0))])
        building_list.set_item_metadata(index, ids[index])
    if selected_building_id.is_empty() and not ids.is_empty():
        selected_building_id = ids[0]
        building_list.select(0)
    _refresh_building_details()
    _refresh_resources()

func _refresh_building_details() -> void:
    var data := EstateManager.get_building_data(selected_building_id)
    if data.is_empty():
        building_details.text = "Seleccioná una instalación."
        upgrade_button.disabled = true
        return
    var level := int(data.get("level", 0))
    var max_level := int(data.get("max_level", 5))
    upgrade_button.disabled = level >= max_level
    building_details.text = "[b]%s[/b]\nNivel: %d/%d\n%s\n\nPróxima mejora: %d denarios\n\nEfectos actuales:\nCapacidad: %s\nMultiplicador de entrenamiento: x%.2f\nNivel de forja: %d\nRecuperación extra: %d\nSeguridad fija: %d" % [data.get("name", selected_building_id), level, max_level, data.get("description", ""), int(data.get("upgrade_cost", 0)), RosterManager.get_capacity_summary(), EstateManager.get_training_multiplier(), EstateManager.get_forge_level(), EstateManager.get_recovery_bonus(), EstateManager.get_security_bonus()]

func _role_name(role_id: String) -> String:
    match role_id:
        "slave": return "Esclavo"
        "gladiator": return "Gladiador"
        _: return role_id.capitalize()
