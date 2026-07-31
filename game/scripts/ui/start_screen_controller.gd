extends Node

const MAIN_SCENE_NAME := "Main"

var overlay: ColorRect
var card: VBoxContainer
var status_label: Label
var name_input: LineEdit
var title_selector: OptionButton
var origin_selector: OptionButton
var origin_details: RichTextLabel
var continue_button: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    for _attempt in range(60):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene != null and scene.name == MAIN_SCENE_NAME and scene.is_inside_tree():
            _build_title_screen(scene)
            return
    push_error("No se pudo montar la pantalla de inicio sobre la escena principal.")

func _build_title_screen(scene: Node) -> void:
    if scene.get_node_or_null("StartScreen") != null:
        return
    overlay = ColorRect.new()
    overlay.name = "StartScreen"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.035, 0.028, 0.024, 0.98)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.z_index = 100
    scene.add_child(overlay)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(620, 560)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 32)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_right", 32)
    margin.add_theme_constant_override("margin_bottom", 28)
    panel.add_child(margin)

    card = VBoxContainer.new()
    card.add_theme_constant_override("separation", 14)
    margin.add_child(card)
    _show_main_menu()

func _clear_card() -> void:
    for child in card.get_children():
        child.queue_free()

func _title(text_value: String, size: int = 30) -> Label:
    var label := Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size)
    return label

func _button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 46)
    button.pressed.connect(callback)
    return button

func _show_main_menu() -> void:
    _clear_card()
    card.add_child(_title("LUDUS", 42))
    card.add_child(_title("GLADIATOR SIMULATOR", 24))

    var subtitle := Label.new()
    subtitle.text = "Forjá una casa de gladiadores. Sobreviví dieciséis semanas."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card.add_child(subtitle)

    continue_button = _button("Continuar campaña", _continue_campaign)
    continue_button.disabled = not SaveManager.has_save()
    continue_button.tooltip_text = "No existe una partida guardada." if continue_button.disabled else "Cargar la campaña más reciente."
    card.add_child(continue_button)
    card.add_child(_button("Nueva campaña", _show_owner_creation))
    card.add_child(_button("Salir", func() -> void: get_tree().quit()))

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var metadata := SaveManager.get_save_metadata()
    if not metadata.is_empty():
        status_label.text = "Guardado disponible — Semana %d" % int(metadata.get("week", metadata.get("day", 1)))
    card.add_child(status_label)

func _continue_campaign() -> void:
    continue_button.disabled = true
    status_label.text = "Cargando campaña..."
    if SaveManager.load_game():
        overlay.queue_free()
    else:
        status_label.text = "No se pudo cargar una partida válida."
        continue_button.disabled = false

func _show_owner_creation() -> void:
    _clear_card()
    card.add_child(_title("NUEVA CAMPAÑA", 30))

    var explanation := Label.new()
    explanation.text = "Elegí quién dirigirá el ludus y el origen de su fortuna. Esta elección define los recursos iniciales de la campaña."
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(explanation)

    title_selector = OptionButton.new()
    title_selector.add_item("Dominus")
    title_selector.set_item_metadata(0, "dominus")
    title_selector.add_item("Domina")
    title_selector.set_item_metadata(1, "domina")
    card.add_child(title_selector)

    name_input = LineEdit.new()
    name_input.placeholder_text = "Nombre del propietario o propietaria"
    name_input.max_length = 32
    card.add_child(name_input)

    origin_selector = OptionButton.new()
    for origin_id in LudusOwnerManager.get_origin_ids():
        var origin := LudusOwnerManager.get_origin(origin_id)
        origin_selector.add_item(str(origin.get("name", origin_id.capitalize())))
        origin_selector.set_item_metadata(origin_selector.item_count - 1, origin_id)
    origin_selector.item_selected.connect(func(_index: int): _refresh_origin_details())
    card.add_child(origin_selector)

    origin_details = RichTextLabel.new()
    origin_details.bbcode_enabled = true
    origin_details.fit_content = true
    origin_details.custom_minimum_size = Vector2(0, 150)
    card.add_child(origin_details)
    _refresh_origin_details()

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card.add_child(status_label)

    card.add_child(_button("Comenzar campaña", _start_new_campaign))
    card.add_child(_button("Volver", _show_main_menu))

func _refresh_origin_details() -> void:
    if origin_details == null or origin_selector == null or origin_selector.selected < 0:
        return
    var origin_id := str(origin_selector.get_item_metadata(origin_selector.selected))
    var origin := LudusOwnerManager.get_origin(origin_id)
    var bonus_lines: Array[String] = []
    var bonuses: Dictionary = origin.get("bonuses", {})
    var labels := {
        "starting_denarii":"Denarios iniciales",
        "starting_food":"Comida inicial",
        "starting_ore":"Mineral inicial",
        "starting_reputation":"Reputación inicial",
        "starting_loyalty":"Lealtad del personal",
        "starting_morale":"Moral del personal"
    }
    for key in labels.keys():
        var value := int(bonuses.get(key, 0))
        if value != 0:
            bonus_lines.append("• %s: %+d" % [labels[key], value])
    var experience_multiplier := float(bonuses.get("gladiator_experience_multiplier", 1.0))
    if experience_multiplier > 1.0:
        bonus_lines.append("• Experiencia de gladiadores: +%d%%" % int(round((experience_multiplier - 1.0) * 100.0)))
    origin_details.text = "[b]%s[/b]\n%s\n\n[b]Bonificaciones[/b]\n%s" % [
        origin.get("name", "Origen"),
        origin.get("description", ""),
        "\n".join(bonus_lines) if not bonus_lines.is_empty() else "Sin bonificaciones."
    ]

func _start_new_campaign() -> void:
    if origin_selector.selected < 0:
        status_label.text = "Seleccioná un origen."
        return
    var title_id := str(title_selector.get_item_metadata(title_selector.selected))
    var origin_id := str(origin_selector.get_item_metadata(origin_selector.selected))
    var display_name := name_input.text.strip_edges()
    if display_name.length() < 2:
        status_label.text = "Ingresá un nombre de al menos dos caracteres."
        return
    SaveManager.delete_save()
    if not LudusOwnerManager.configure_owner(title_id, display_name, origin_id):
        status_label.text = "No se pudo configurar el propietario del ludus."
        return
    SaveManager.save_game()
    overlay.queue_free()
