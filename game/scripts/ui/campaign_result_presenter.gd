extends Node

const MAIN_SCENE_NAME := "Main"

var overlay: ColorRect
var card: VBoxContainer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    CampaignManager.campaign_finished.connect(_on_campaign_finished)
    SaveManager.load_completed.connect(func(_path: String): call_deferred("_show_loaded_result_if_needed"))

func _show_loaded_result_if_needed() -> void:
    var summary := CampaignManager.get_summary()
    if bool(summary.get("campaign_over", false)):
        _show_result(bool(summary.get("victory", false)), str(summary.get("defeat_reason", "")))

func _on_campaign_finished(victory: bool, reason: String) -> void:
    SaveManager.call_deferred("save_game")
    call_deferred("_show_result", victory, reason)

func _show_result(victory: bool, reason: String) -> void:
    var scene := get_tree().current_scene
    if scene == null or scene.name != MAIN_SCENE_NAME:
        return
    _ensure_overlay(scene)
    _clear_card()
    var summary := CampaignManager.get_summary()
    var owner := LudusOwnerManager.get_profile()
    var rank: Dictionary = summary.get("rank", {})

    card.add_child(_make_label("VICTORIA DE CAMPAÑA" if victory else "CAMPAÑA FINALIZADA", 34))
    card.add_child(_make_label("%s %s" % [LudusOwnerManager.get_title_label(), str(owner.get("display_name", ""))], 20))

    var details := RichTextLabel.new()
    details.bbcode_enabled = true
    details.fit_content = true
    details.custom_minimum_size = Vector2(0, 240)
    details.text = "Semana: %d de %d\nVictorias: %d | Derrotas: %d\nRango final: %s\nReputación: %d | Denarios: %d\nObjetivos: %d de %d\n\n%s" % [GameState.get_week(), int(summary.get("final_week", 16)), int(summary.get("wins", 0)), int(summary.get("losses", 0)), str(rank.get("name", "Ludus desconocido")), GameState.reputation, GameState.denarii, CampaignManager.completed_objectives.size(), CampaignManager.OBJECTIVES.size(), reason]
    card.add_child(details)

    var menu_button := Button.new()
    menu_button.text = "Guardar y volver al menú principal"
    menu_button.custom_minimum_size = Vector2(0, 48)
    menu_button.pressed.connect(_return_to_title)
    card.add_child(menu_button)
    overlay.visible = true

func _ensure_overlay(scene: Node) -> void:
    if overlay != null and is_instance_valid(overlay):
        return
    overlay = ColorRect.new()
    overlay.name = "CampaignResultScreen"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.03, 0.025, 0.02, 0.97)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.z_index = 120
    scene.add_child(overlay)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(650, 500)
    center.add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 34)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_right", 34)
    margin.add_theme_constant_override("margin_bottom", 28)
    panel.add_child(margin)
    card = VBoxContainer.new()
    card.add_theme_constant_override("separation", 16)
    margin.add_child(card)

func _clear_card() -> void:
    for child in card.get_children():
        child.queue_free()

func _make_label(text_value: String, size: int) -> Label:
    var label := Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size)
    return label

func _return_to_title() -> void:
    if not SaveManager.save_game():
        return
    overlay.visible = false
    StartScreenController.show_main_menu()
