extends Node

const ROOT_NAME := "InitialGladiatorSelection"

var market_panel: VBoxContainer
var market_list: ItemList
var market_details: RichTextLabel
var buy_button: Button
var selection_root: VBoxContainer
var feedback_label: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    MarketManager.market_changed.connect(_refresh)
    MarketManager.purchase_failed.connect(_show_feedback)
    UniqueGladiatorManager.unique_gladiators_changed.connect(_refresh)
    call_deferred("_bind")

func _bind() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    market_panel = scene.get_node_or_null("Margin/VBox/Tabs/Mercado") as VBoxContainer
    market_list = scene.get_node_or_null("Margin/VBox/Tabs/Mercado/MarketList") as ItemList
    market_details = scene.get_node_or_null("Margin/VBox/Tabs/Mercado/MarketDetails") as RichTextLabel
    buy_button = scene.get_node_or_null("Margin/VBox/Tabs/Mercado/BuyOffer") as Button
    if market_panel == null:
        return
    _ensure_selection_root()
    _refresh()

func _ensure_selection_root() -> void:
    selection_root = market_panel.get_node_or_null(ROOT_NAME) as VBoxContainer
    if selection_root != null:
        return
    selection_root = VBoxContainer.new()
    selection_root.name = ROOT_NAME
    selection_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    selection_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    selection_root.add_theme_constant_override("separation", 8)
    market_panel.add_child(selection_root)
    market_panel.move_child(selection_root, 0)

func _refresh() -> void:
    if market_panel == null or not is_instance_valid(market_panel):
        call_deferred("_bind")
        return
    var choosing_first: bool = not UniqueGladiatorManager.first_purchase_completed and not RosterManager.has_gladiator()
    selection_root.visible = choosing_first
    _set_tutorial_occluded(choosing_first)
    if market_list != null:
        market_list.visible = not choosing_first
    if market_details != null:
        market_details.visible = not choosing_first
    if buy_button != null:
        buy_button.visible = not choosing_first
    if choosing_first:
        _render_candidates()

func _set_tutorial_occluded(occluded: bool) -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var tutorial_panel := scene.get_node_or_null("CampaignTutorial") as Control
    if tutorial_panel == null:
        return
    if occluded:
        tutorial_panel.visible = false
    elif LudusOwnerManager.should_show_tutorial():
        tutorial_panel.visible = true

func _render_candidates() -> void:
    for child in selection_root.get_children():
        child.queue_free()

    var title := Label.new()
    title.text = "ELEGÍ AL PRIMER GLADIADOR DEL LUDUS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    selection_root.add_child(title)

    var introduction := Label.new()
    introduction.text = "Solo podés contratar a uno. Los otros dos pasarán a casas rivales y podrán reaparecer durante la campaña."
    introduction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    introduction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selection_root.add_child(introduction)

    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    selection_root.add_child(scroll)

    var cards := HBoxContainer.new()
    cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cards.add_theme_constant_override("separation", 10)
    scroll.add_child(cards)

    for offer in UniqueGladiatorManager.get_initial_candidate_offers():
        cards.add_child(_build_candidate_card(offer))

    feedback_label = Label.new()
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selection_root.add_child(feedback_label)

func _build_candidate_card(offer: Dictionary) -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(320, 430)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    margin.add_child(box)

    var portrait := Label.new()
    portrait.custom_minimum_size = Vector2(0, 70)
    portrait.text = "RETRATO\nPENDIENTE"
    portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    portrait.add_theme_font_size_override("font_size", 16)
    box.add_child(portrait)

    var name_label := Label.new()
    name_label.text = str(offer.get("name", "Gladiador"))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 20)
    box.add_child(name_label)

    var identity := Label.new()
    identity.text = "%s · %s" % [_gender_name(str(offer.get("gender", "unknown"))), str(offer.get("origin", "Desconocido"))]
    identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(identity)

    var stats := Label.new()
    stats.text = "FUE %d · AGI %d · RES %d\nINT %d · TEC %d · VIDA %d" % [
        int(offer.get("strength", 5)), int(offer.get("agility", 5)), int(offer.get("endurance", 5)),
        int(offer.get("intelligence", 5)), int(offer.get("technique", 5)), int(offer.get("health", 50))
    ]
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(stats)

    var management := Label.new()
    management.text = "Lealtad %d · Moral %d" % [int(offer.get("loyalty", 50)), int(offer.get("morale", 50))]
    management.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(management)

    var traits := Label.new()
    var trait_names: Array[String] = []
    for trait_id in offer.get("traits", []):
        trait_names.append(TraitManager.get_trait_name(str(trait_id)))
    traits.text = "Rasgos: %s" % (", ".join(trait_names) if not trait_names.is_empty() else "Ninguno")
    traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(traits)

    var history := Label.new()
    history.text = str(offer.get("history", ""))
    history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    history.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(history)

    var specializations := Label.new()
    var names: Array[String] = []
    for specialization_id in offer.get("recommended_specializations", []):
        names.append(GladiatorProgressionManager.get_specialization_name(str(specialization_id)))
    specializations.text = "Potencial: %s" % (", ".join(names) if not names.is_empty() else "Flexible")
    specializations.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(specializations)

    var consequence := Label.new()
    consequence.text = _consequence_text(str(offer.get("unique_gladiator_id", "")))
    consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(consequence)

    var choose := Button.new()
    choose.text = "Contratar por %d denarios" % int(offer.get("price", 0))
    choose.disabled = GameState.denarii < int(offer.get("price", 0))
    choose.tooltip_text = "Esta decisión es permanente. Los otros candidatos pasarán a casas rivales."
    choose.pressed.connect(_choose_candidate.bind(str(offer.get("id", "")), str(offer.get("name", "Gladiador"))))
    box.add_child(choose)
    return panel

func _choose_candidate(offer_id: String, candidate_name: String) -> void:
    if feedback_label != null:
        feedback_label.text = "Contratando a %s..." % candidate_name
    MarketManager.buy_offer(offer_id)

func _show_feedback(reason: String) -> void:
    if feedback_label != null and is_instance_valid(feedback_label):
        feedback_label.text = reason

func _gender_name(value: String) -> String:
    match value:
        "female": return "Gladiadora"
        "male": return "Gladiador"
        _: return "Gladiador"

func _consequence_text(gladiator_id: String) -> String:
    match gladiator_id:
        "marcus_varro": return "Elección segura: adaptación rápida y buena popularidad. Odran y Neria reforzarán a tus rivales."
        "odran": return "Elección de alto impacto: gran fuerza, pero baja lealtad. Marcus y Neria crecerán en casas rivales."
        "neria": return "Elección técnica: movilidad, precisión y ventaja contra bestias. Marcus y Odran serán futuros rivales."
        _: return "Los candidatos no elegidos serán contratados por casas rivales."
