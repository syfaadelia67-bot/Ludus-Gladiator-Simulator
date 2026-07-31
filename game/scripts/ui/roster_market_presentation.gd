extends Node

var roster_list: ItemList
var roster_details: RichTextLabel
var market_list: ItemList
var market_details: RichTextLabel

func _ready() -> void:
    call_deferred("_bind")

func _bind() -> void:
    var root := get_tree().current_scene
    if root == null:
        return
    roster_list = root.get_node_or_null("Margin/VBox/Tabs/Personal/Left/RosterList") as ItemList
    roster_details = root.get_node_or_null("Margin/VBox/Tabs/Personal/Left/Details") as RichTextLabel
    market_list = root.get_node_or_null("Margin/VBox/Tabs/Mercado/MarketList") as ItemList
    market_details = root.get_node_or_null("Margin/VBox/Tabs/Mercado/MarketDetails") as RichTextLabel
    if roster_list != null:
        roster_list.item_selected.connect(func(_index: int): call_deferred("_refresh_roster_card"))
    if market_list != null:
        market_list.item_selected.connect(func(_index: int): call_deferred("_refresh_market_card"))
    RosterManager.roster_changed.connect(func(): call_deferred("_refresh_roster_card"))
    MarketManager.market_changed.connect(func(): call_deferred("_refresh_market_card"))
    GladiatorProgressionManager.progression_changed.connect(func(): call_deferred("_refresh_roster_card"))
    TraitManager.traits_changed.connect(func(_person_id: String): call_deferred("_refresh_roster_card"))
    _refresh_roster_card()
    _refresh_market_card()

func _refresh_roster_card() -> void:
    if roster_list == null or roster_details == null or roster_list.selected < 0:
        return
    var person_id := str(roster_list.get_item_metadata(roster_list.selected))
    var person = RosterManager.get_person(person_id)
    if person == null:
        return
    var record: Dictionary = GladiatorProgressionManager.get_record(person.id) if person.role == "gladiator" else {}
    var trait_names: Array[String] = []
    for trait_id in person.traits:
        trait_names.append(TraitManager.get_trait_name(str(trait_id)))
    var progression_line := ""
    var value_line := ""
    if person.role == "gladiator":
        progression_line = "\nNivel: %d | Especialización: %s | Puntos: %d" % [
            int(record.get("level", 1)),
            GladiatorProgressionManager.get_specialization_name(str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION))),
            int(record.get("skill_points", 0))
        ]
        value_line = "\nValor estimado: %d denarios" % MarketValuation.person_value(person, record)
    roster_details.text = "[b]%s[/b]\nOrigen: %s | Rol: %s%s\nFUE %d | AGI %d | RES %d | INT %d | TEC %d\nVida base: %d | Vida de combate: %d | Energía: %d\nLealtad: %d | Moral: %d | Fatiga: %d\nAtaque: %d | Defensa: %d%s\nRasgos permanentes: %s" % [
        person.display_name,
        person.origin,
        _role_name(person.role),
        progression_line,
        person.strength,
        person.agility,
        person.endurance,
        person.intelligence,
        person.technique,
        person.health,
        person.get_max_health(),
        person.get_max_energy(),
        person.loyalty,
        person.morale,
        person.fatigue,
        person.get_base_attack(),
        person.get_base_defense(),
        value_line,
        ", ".join(trait_names) if not trait_names.is_empty() else "Ninguno"
    ]

func _refresh_market_card() -> void:
    if market_list == null or market_details == null or market_list.selected < 0:
        return
    var offer_id := str(market_list.get_item_metadata(market_list.selected))
    var offer := MarketManager.get_offer(offer_id)
    if offer.is_empty():
        return
    var trait_names: Array[String] = []
    for trait_id in offer.get("traits", []):
        trait_names.append(TraitManager.get_trait_name(str(trait_id)))
    market_details.text = "[b]%s[/b] — %s de %s\nFUE %d | AGI %d | RES %d | INT %d | TEC %d\nVida base: %d | Lealtad: %d\nRasgos de origen: %s\nValor calculado: %d denarios" % [
        offer.get("name", "?"),
        _role_name(str(offer.get("role", "slave"))),
        offer.get("origin", "?"),
        int(offer.get("strength", 5)),
        int(offer.get("agility", 5)),
        int(offer.get("endurance", 5)),
        int(offer.get("intelligence", 5)),
        int(offer.get("technique", 5)),
        int(offer.get("health", 50)),
        int(offer.get("loyalty", 50)),
        ", ".join(trait_names) if not trait_names.is_empty() else "Ninguno",
        int(offer.get("price", MarketValuation.offer_value(offer)))
    ]

func _role_name(role_id: String) -> String:
    match role_id:
        "slave": return "Esclavo"
        "gladiator": return "Gladiador"
        "retired": return "Retirado"
        _: return role_id.capitalize()
