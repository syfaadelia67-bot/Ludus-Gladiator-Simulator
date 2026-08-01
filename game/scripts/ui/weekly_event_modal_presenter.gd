extends Node

const MAIN_SCENE_NAME := "Main"

var overlay: ColorRect
var card: VBoxContainer
var feedback: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    EventManager.event_started.connect(_on_event_started)
    EventManager.event_resolved.connect(_on_event_resolved)
    SaveManager.load_completed.connect(func(_path: String): call_deferred("_show_pending_event_if_needed"))
    call_deferred("_show_pending_event_if_needed")

func _on_event_started(event: Dictionary) -> void:
    call_deferred("_show_event", event)

func _on_event_resolved(_result: Dictionary) -> void:
    _hide_modal()

func _show_pending_event_if_needed() -> void:
    var event := EventManager.get_pending_event()
    if not event.is_empty():
        _show_event(event)

func _show_event(event: Dictionary) -> void:
    var scene := get_tree().current_scene
    if scene == null or scene.name != MAIN_SCENE_NAME:
        return
    _ensure_modal(scene)
    _clear_card()

    var week := int(event.get("week", GameState.get_week()))
    var chapter := CampaignManager.get_chapter_for_week(week)

    var kicker := Label.new()
    kicker.text = "EVENTO SEMANAL · SEMANA %d" % week
    kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(kicker)

    var title := Label.new()
    title.text = str(event.get("title", "Evento de campaña"))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.add_theme_font_size_override("font_size", 26)
    card.add_child(title)

    var chapter_label := Label.new()
    chapter_label.text = str(chapter.get("title", "Campaña"))
    chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(chapter_label)

    var body := Label.new()
    body.text = str(event.get("text", ""))
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.custom_minimum_size = Vector2(0, 80)
    card.add_child(body)

    var separator := HSeparator.new()
    card.add_child(separator)

    for choice_variant in event.get("choices", []):
        if not choice_variant is Dictionary:
            continue
        var choice: Dictionary = choice_variant
        var choice_id := str(choice.get("id", ""))
        var unmet := EventManager.get_unmet_requirements(choice)

        var button := Button.new()
        button.text = str(choice.get("label", choice_id))
        button.custom_minimum_size = Vector2(0, 44)
        button.disabled = not unmet.is_empty()
        button.tooltip_text = unmet if not unmet.is_empty() else "Tomar esta decisión"
        button.pressed.connect(_resolve_choice.bind(choice_id))
        card.add_child(button)

        var consequence := Label.new()
        consequence.text = "Requisito: %s" % unmet if not unmet.is_empty() else _describe_effects(choice.get("effects", {}))
        consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        card.add_child(consequence)

    feedback = Label.new()
    feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card.add_child(feedback)

    overlay.visible = true
    overlay.grab_focus()

func _ensure_modal(scene: Node) -> void:
    if overlay != null and is_instance_valid(overlay):
        return
    overlay = ColorRect.new()
    overlay.name = "WeeklyEventModal"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.02, 0.018, 0.016, 0.88)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.z_index = 140
    scene.add_child(overlay)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(620, 430)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_top", 24)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_bottom", 24)
    panel.add_child(margin)

    card = VBoxContainer.new()
    card.add_theme_constant_override("separation", 10)
    margin.add_child(card)

func _clear_card() -> void:
    for child in card.get_children():
        child.queue_free()

func _resolve_choice(choice_id: String) -> void:
    var result := EventManager.resolve_choice(choice_id)
    if not bool(result.get("success", false)):
        if feedback != null:
            feedback.text = str(result.get("reason", "No se pudo aplicar la decisión."))
        return
    _hide_modal()

func _hide_modal() -> void:
    if overlay != null and is_instance_valid(overlay):
        overlay.visible = false

func _describe_effects(effect_data: Dictionary) -> String:
    var labels := {
        "denarii":"Denarios", "food":"Comida", "ore":"Mineral", "reputation":"Reputación",
        "intelligence":"Inteligencia", "security":"Seguridad", "morale_all":"Moral de todos",
        "loyalty_all":"Lealtad de todos", "training_all":"Entrenamiento de todos"
    }
    var parts: Array[String] = []
    for key in labels.keys():
        var value := int(effect_data.get(key, 0))
        if value != 0:
            parts.append("%s: %+d" % [labels[key], value])
    var timed = effect_data.get("timed", {})
    if timed is Dictionary and not timed.is_empty():
        parts.append("%s durante %d semana(s)" % [timed.get("name", "Efecto temporal"), int(timed.get("weeks", 1))])
    return "Consecuencias: %s" % ", ".join(parts) if not parts.is_empty() else "Sin costo ni efecto directo"
