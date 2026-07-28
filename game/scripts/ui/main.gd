extends Control

@onready var resources_label: Label = $Margin/VBox/Resources
@onready var advance_button: Button = $Margin/VBox/TopButtons/AdvanceDay
@onready var refresh_market_button: Button = $Margin/VBox/TopButtons/RefreshMarket
@onready var capacity_label: Label = $Margin/VBox/TopButtons/Capacity
@onready var roster_list: ItemList = $Margin/VBox/Tabs/Personal/Left/RosterList
@onready var details: RichTextLabel = $Margin/VBox/Tabs/Personal/Left/Details
@onready var job_selector: OptionButton = $Margin/VBox/Tabs/Personal/Left/JobRow/JobSelector
@onready var assign_button: Button = $Margin/VBox/Tabs/Personal/Left/JobRow/AssignJob
@onready var log: RichTextLabel = $Margin/VBox/Tabs/Personal/Log
@onready var market_list: ItemList = $Margin/VBox/Tabs/Mercado/MarketList
@onready var market_details: RichTextLabel = $Margin/VBox/Tabs/Mercado/MarketDetails
@onready var buy_button: Button = $Margin/VBox/Tabs/Mercado/BuyOffer
@onready var building_list: ItemList = $Margin/VBox/Tabs/Finca/BuildingList
@onready var building_details: RichTextLabel = $Margin/VBox/Tabs/Finca/BuildingPanel/BuildingDetails
@onready var upgrade_button: Button = $Margin/VBox/Tabs/Finca/BuildingPanel/UpgradeBuilding
@onready var recipe_list: ItemList = $Margin/VBox/Tabs/Forja/RecipeList
@onready var recipe_details: RichTextLabel = $Margin/VBox/Tabs/Forja/ForgePanel/RecipeDetails
@onready var craft_button: Button = $Margin/VBox/Tabs/Forja/ForgePanel/CraftItem
@onready var inventory: RichTextLabel = $Margin/VBox/Tabs/Forja/ForgePanel/Inventory
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

var selected_person_id := ""
var selected_offer_id := ""
var selected_building_id := ""
var selected_recipe_id := ""
var job_ids: Array[String] = []
var gladiator_ids: Array[String] = []
var tactic_ids: Array[String] = []

func _ready() -> void:
    advance_button.pressed.connect(_on_advance_day)
    refresh_market_button.pressed.connect(_on_refresh_market)
    roster_list.item_selected.connect(_on_person_selected)
    market_list.item_selected.connect(_on_offer_selected)
    building_list.item_selected.connect(_on_building_selected)
    recipe_list.item_selected.connect(_on_recipe_selected)
    assign_button.pressed.connect(_on_assign_job)
    buy_button.pressed.connect(_on_buy_offer)
    upgrade_button.pressed.connect(_on_upgrade_building)
    craft_button.pressed.connect(_on_craft_item)
    start_duel_button.pressed.connect(_on_start_duel)
    GameState.resources_changed.connect(_refresh_resources)
    GameState.day_advanced.connect(_on_day_advanced)
    GameState.daily_report.connect(_on_daily_report)
    RosterManager.roster_changed.connect(_refresh_roster)
    MarketManager.market_changed.connect(_refresh_market)
    MarketManager.purchase_completed.connect(_on_purchase_completed)
    MarketManager.purchase_failed.connect(_on_action_failed)
    EstateManager.estate_changed.connect(_refresh_estate)
    EstateManager.upgrade_completed.connect(_on_upgrade_completed)
    EstateManager.upgrade_failed.connect(_on_action_failed)
    EquipmentManager.inventory_changed.connect(_refresh_inventory)
    EquipmentManager.craft_completed.connect(_on_craft_completed)
    EquipmentManager.craft_failed.connect(_on_action_failed)
    CombatManager.combat_finished.connect(_on_combat_finished)
    CombatManager.combat_failed.connect(_on_action_failed)
    _populate_jobs()
    _populate_tactics()
    _refresh_resources()
    _refresh_roster()
    _refresh_market()
    _refresh_estate()
    _refresh_recipes()
    _refresh_inventory()
    _refresh_gladiators()

func _populate_jobs() -> void:
    job_selector.clear()
    job_ids = RosterManager.get_job_ids()
    for job_id in job_ids:
        job_selector.add_item(RosterManager.get_job_name(job_id))

func _populate_tactics() -> void:
    tactic_selector.clear()
    tactic_ids = CombatManager.get_tactic_ids()
    for tactic_id in tactic_ids:
        tactic_selector.add_item(CombatManager.get_tactic_name(tactic_id))

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

func _on_building_selected(index: int) -> void:
    selected_building_id = str(building_list.get_item_metadata(index))
    _refresh_building_details()

func _on_recipe_selected(index: int) -> void:
    selected_recipe_id = str(recipe_list.get_item_metadata(index))
    _refresh_recipe_details()

func _on_assign_job() -> void:
    if selected_person_id.is_empty() or job_selector.selected < 0:
        _append_warning("Seleccioná un personaje y un trabajo.")
        return
    var job_id := job_ids[job_selector.selected]
    if RosterManager.assign_job(selected_person_id, job_id):
        var person = RosterManager.get_person(selected_person_id)
        log.append_text("\n%s fue asignado a %s." % [person.display_name, RosterManager.get_job_name(job_id)])

func _on_buy_offer() -> void:
    if selected_offer_id.is_empty():
        _append_warning("Seleccioná una oferta del mercado.")
        return
    MarketManager.buy_offer(selected_offer_id)

func _on_upgrade_building() -> void:
    if selected_building_id.is_empty():
        _append_warning("Seleccioná una instalación.")
        return
    EstateManager.upgrade(selected_building_id)

func _on_craft_item() -> void:
    if selected_recipe_id.is_empty():
        _append_warning("Seleccioná una receta.")
        return
    EquipmentManager.craft(selected_recipe_id)

func _on_start_duel() -> void:
    if gladiator_selector.selected < 0 or gladiator_ids.is_empty():
        arena_result.text = "No hay gladiadores disponibles."
        return
    var fighter_id := gladiator_ids[gladiator_selector.selected]
    var tactic_id := tactic_ids[tactic_selector.selected] if tactic_selector.selected >= 0 else "balanced"
    start_duel_button.disabled = true
    arena_result.text = "El combate está comenzando..."
    CombatManager.simulate_duel(fighter_id, tactic_id)
    start_duel_button.disabled = false

func _on_purchase_completed(person_name_value: String, price: int) -> void:
    log.append_text("\n[color=gold]Compraste a %s por %d denarios.[/color]" % [person_name_value, price])
    selected_offer_id = ""

func _on_upgrade_completed(building_id: String, new_level: int) -> void:
    var data := EstateManager.get_building_data(building_id)
    log.append_text("\n[color=gold]%s mejorado a nivel %d.[/color]" % [data.get("name", building_id), new_level])
    _refresh_recipes()

func _on_craft_completed(item_name: String, cost_ore: int, cost_denarii: int) -> void:
    log.append_text("\n[color=gold]Fabricaste %s por %d mineral y %d denarios.[/color]" % [item_name, cost_ore, cost_denarii])

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
    log.append_text("\n[color=gold]%s terminó un duelo en %d rondas.[/color]" % [result.get("fighter", "El gladiador"), int(result.get("rounds", 0))])

func _set_bar(bar: ProgressBar, value: int, maximum: int) -> void:
    bar.max_value = maxi(1, maximum)
    bar.value = clampi(value, 0, maximum)
    bar.tooltip_text = "%d/%d" % [value, maximum]

func _on_action_failed(reason: String) -> void:
    _append_warning(reason)
    arena_result.text = reason

func _append_warning(text: String) -> void:
    log.append_text("\n[color=orange]%s[/color]" % text)

func _on_day_advanced(day: int) -> void:
    log.append_text("\n\n[b]Día %d[/b]" % day)

func _on_daily_report(report: Dictionary) -> void:
    log.append_text("\nMineral producido: %d" % int(report.get("ore", 0)))
    log.append_text("\nSeguridad generada: %d" % int(report.get("security", 0)))
    log.append_text("\nInformación obtenida: %d" % int(report.get("intel", 0)))
    log.append_text("\nEntrenamiento total: %d" % int(report.get("training", 0)))
    for person_name_value in report.get("promotions", []):
        log.append_text("\n[color=gold]%s completó su formación y ahora es gladiador.[/color]" % person_name_value)

func _refresh_resources() -> void:
    resources_label.text = GameState.get_resource_summary()
    capacity_label.text = "Capacidad: %s" % RosterManager.get_capacity_summary()

func _refresh_roster() -> void:
    roster_list.clear()
    var people := RosterManager.get_people()
    for index in range(people.size()):
        var person = people[index]
        roster_list.add_item("%s — %s — %s" % [person.display_name, _role_name(person.role), RosterManager.get_job_name(person.job)])
        roster_list.set_item_metadata(index, person.id)
    if not people.is_empty():
        if RosterManager.get_person(selected_person_id) == null:
            selected_person_id = people[0].id
        for index in range(people.size()):
            if people[index].id == selected_person_id:
                roster_list.select(index)
                break
    _refresh_details()
    _refresh_resources()
    _refresh_gladiators()

func _refresh_details() -> void:
    var person = RosterManager.get_person(selected_person_id)
    if person == null:
        details.text = "Seleccioná un personaje."
        assign_button.disabled = true
        return
    assign_button.disabled = false
    var trait_text := ", ".join(person.traits) if not person.traits.is_empty() else "Ninguno"
    details.text = "[b]%s[/b]\nOrigen: %s | Rol: %s\nFuerza: %d | Agilidad: %d | Resistencia: %d | Inteligencia: %d\nLealtad: %d | Moral: %d | Fatiga: %d\nEntrenamiento: %d/100\nAtaque: %d | Defensa: %d | Vida: %d | Energía: %d\nRasgos: %s" % [person.display_name, person.origin, _role_name(person.role), person.strength, person.agility, person.endurance, person.intelligence, person.loyalty, person.morale, person.fatigue, person.training, person.get_base_attack(), person.get_base_defense(), person.get_max_health(), person.get_max_energy(), trait_text]
    var current_job_index := job_ids.find(person.job)
    if current_job_index >= 0:
        job_selector.select(current_job_index)

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

func _refresh_recipes() -> void:
    recipe_list.clear()
    var ids := EquipmentManager.get_recipe_ids()
    for index in range(ids.size()):
        var data := EquipmentManager.get_recipe(ids[index])
        var status := "Disponible" if bool(data.get("unlocked", false)) else "Bloqueada"
        recipe_list.add_item("%s — %s" % [data.get("name", ids[index]), status])
        recipe_list.set_item_metadata(index, ids[index])
    if selected_recipe_id.is_empty() and not ids.is_empty():
        selected_recipe_id = ids[0]
        recipe_list.select(0)
    _refresh_recipe_details()

func _refresh_recipe_details() -> void:
    var data := EquipmentManager.get_recipe(selected_recipe_id)
    if data.is_empty():
        recipe_details.text = "Seleccioná una receta."
        craft_button.disabled = true
        return
    var unlocked := bool(data.get("unlocked", false))
    craft_button.disabled = not unlocked
    var stat_text := "Poder: %d" % int(data.get("power", 0)) if data.has("power") else "Defensa: %d" % int(data.get("defense", 0))
    recipe_details.text = "[b]%s[/b]\nTipo: %s | %s\nNivel de forja requerido: %d\nCosto: %d mineral y %d denarios\nEstado: %s" % [data.get("name", selected_recipe_id), data.get("type", "item"), stat_text, int(data.get("forge_level", 1)), int(data.get("ore", 0)), int(data.get("denarii", 0)), "Disponible" if unlocked else "Bloqueada"]

func _refresh_inventory() -> void:
    var items := EquipmentManager.get_inventory()
    if items.is_empty():
        inventory.text = "Vacío"
        return
    var lines: Array[String] = []
    for item in items:
        var owner := str(item.get("equipped_by", ""))
        var equipped_text := "" if owner.is_empty() else " — Equipado"
        lines.append("• %s — Calidad %s%s" % [item.get("name", "Objeto"), item.get("quality", "Común"), equipped_text])
    inventory.text = "\n".join(lines)

func _role_name(role_id: String) -> String:
    match role_id:
        "slave": return "Esclavo"
        "gladiator": return "Gladiador"
        _: return role_id.capitalize()