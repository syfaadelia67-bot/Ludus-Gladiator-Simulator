extends Node

const MAIN_SCENE_NAME := "Main"
const MODAL_NAME := "ArenaCombatResultModal"

var modal_layer: CanvasLayer
var overlay: ColorRect
var result_data: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    CombatManager.combat_finished.connect(_on_combat_finished)

func _on_combat_finished(result: Dictionary) -> void:
    result_data = result.duplicate(true)
    call_deferred("_show_result")

func _show_result() -> void:
    var scene := get_tree().current_scene
    if scene == null or scene.name != MAIN_SCENE_NAME:
        push_error("No se pudo mostrar el resultado de Arena porque la escena Main no está activa.")
        return

    _destroy_modal_immediately()
    _close_conflicting_overlays(scene)

    if TutorialController.has_method("suspend_for_modal"):
        TutorialController.suspend_for_modal()
    if FincaHubController.has_method("open_system"):
        FincaHubController.open_system("arena")

    modal_layer = CanvasLayer.new()
    modal_layer.name = MODAL_NAME
    modal_layer.layer = 200
    scene.add_child(modal_layer)

    overlay = ColorRect.new()
    overlay.name = "Overlay"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.018, 0.014, 0.01, 0.96)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    modal_layer.add_child(overlay)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(760, 560)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_top", 24)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_bottom", 24)
    panel.add_child(margin)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 12)
    margin.add_child(content)

    var victory := bool(result_data.get("victory", false))
    var surrendered := bool(result_data.get("surrendered", false))

    var title := Label.new()
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.text = "VICTORIA" if victory else ("RENDICIÓN" if surrendered else "DERROTA")
    content.add_child(title)

    var summary := Label.new()
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    summary.text = "%s contra %s · %d rondas\nPremio: %d denarios · Reputación: %+d%s" % [
        str(result_data.get("fighter", "Gladiador")),
        str(result_data.get("enemy", "Rival")),
        int(result_data.get("rounds", 0)),
        int(result_data.get("reward", 0)),
        int(result_data.get("reputation", 0)),
        "\nHerida: %s" % str(result_data.get("injury", "")) if not str(result_data.get("injury", "")).is_empty() else ""
    ]
    content.add_child(summary)

    var combat_log := RichTextLabel.new()
    combat_log.bbcode_enabled = true
    combat_log.fit_content = false
    combat_log.scroll_active = true
    combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    combat_log.custom_minimum_size = Vector2(0, 360)
    combat_log.append_text("[b]Crónica del combate[/b]\n\n")
    for entry: Variant in result_data.get("log", []):
        combat_log.append_text("%s\n" % str(entry))
    content.add_child(combat_log)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_END
    actions.add_theme_constant_override("separation", 10)
    content.add_child(actions)

    var arena_button := Button.new()
    arena_button.text = "Volver a Arena"
    arena_button.custom_minimum_size = Vector2(180, 44)
    arena_button.pressed.connect(_leave_result.bind("arena"))
    actions.add_child(arena_button)

    var finca_button := Button.new()
    finca_button.text = "Volver a la finca"
    finca_button.custom_minimum_size = Vector2(180, 44)
    finca_button.pressed.connect(_leave_result.bind("finca"))
    actions.add_child(finca_button)

func _leave_result(destination: String) -> void:
    _destroy_modal_immediately()
    result_data.clear()

    if destination == "finca":
        FincaHubController.show_finca()
    else:
        FincaHubController.open_system("arena")

    if TutorialController.has_method("resume_after_modal"):
        TutorialController.resume_after_modal()

func _destroy_modal_immediately() -> void:
    if modal_layer != null and is_instance_valid(modal_layer):
        modal_layer.free()
    modal_layer = null
    overlay = null

    var scene := get_tree().current_scene
    if scene != null:
        var stale_modal := scene.get_node_or_null(MODAL_NAME)
        if stale_modal != null and is_instance_valid(stale_modal):
            stale_modal.free()
        var legacy_overlay := scene.get_node_or_null("ArenaCombatResult")
        if legacy_overlay != null and is_instance_valid(legacy_overlay):
            legacy_overlay.free()

func _close_conflicting_overlays(scene: Node) -> void:
    if GladiatorDossierPresenter.has_method("_close"):
        GladiatorDossierPresenter.call("_close")

    for node_name in ["ArenaOpponentPreview", "ArenaFinaleWarning"]:
        var control := scene.get_node_or_null(node_name) as Control
        if control != null:
            control.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
    if modal_layer != null and is_instance_valid(modal_layer) and event.is_action_pressed("ui_cancel"):
        _leave_result("finca")
        get_viewport().set_input_as_handled()
