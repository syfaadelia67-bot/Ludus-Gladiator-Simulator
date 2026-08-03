extends Node

const MAIN_SCENE_NAME := "Main"
const ATTACH_ATTEMPTS := 180

var overlay: ColorRect
var title_label: Label
var summary_label: Label
var log_label: RichTextLabel
var close_button: Button
var finca_button: Button
var skip_button: Button
var playback_token: int = 0
var cached_result: Dictionary = {}
var attach_in_progress := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    CombatManager.combat_finished.connect(_on_combat_finished)
    get_tree().tree_changed.connect(_on_tree_changed)
    call_deferred("_attach_when_ready")

func _on_tree_changed() -> void:
    if overlay == null or not is_instance_valid(overlay):
        call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    if attach_in_progress:
        return
    if overlay != null and is_instance_valid(overlay):
        return
    attach_in_progress = true
    for _attempt in range(ATTACH_ATTEMPTS):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null or scene.name != MAIN_SCENE_NAME:
            continue
        var existing := scene.get_node_or_null("ArenaCombatResult") as ColorRect
        if existing != null:
            overlay = existing
            _cache_overlay_controls()
        else:
            _build_overlay(scene)
        attach_in_progress = false
        if not cached_result.is_empty():
            call_deferred("_present_result")
        return
    attach_in_progress = false
    push_error("No se pudo montar el resultado persistente de combate en la escena Main.")

func _cache_overlay_controls() -> void:
    if overlay == null:
        return
    title_label = overlay.get_node_or_null("Margin/Panel/Content/Title") as Label
    summary_label = overlay.get_node_or_null("Margin/Panel/Content/Summary") as Label
    log_label = overlay.get_node_or_null("Margin/Panel/Content/CombatLog") as RichTextLabel
    skip_button = overlay.get_node_or_null("Margin/Panel/Content/Actions/Skip") as Button
    close_button = overlay.get_node_or_null("Margin/Panel/Content/Actions/Close") as Button
    finca_button = overlay.get_node_or_null("Margin/Panel/Content/Actions/Finca") as Button

func _build_overlay(scene: Node) -> void:
    overlay = ColorRect.new()
    overlay.name = "ArenaCombatResult"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.02, 0.018, 0.016, 0.96)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.z_index = 220
    overlay.visible = false
    scene.add_child(overlay)

    var margin := MarginContainer.new()
    margin.name = "Margin"
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 96)
    margin.add_theme_constant_override("margin_top", 54)
    margin.add_theme_constant_override("margin_right", 96)
    margin.add_theme_constant_override("margin_bottom", 54)
    overlay.add_child(margin)

    var panel := PanelContainer.new()
    panel.name = "Panel"
    margin.add_child(panel)

    var content := VBoxContainer.new()
    content.name = "Content"
    content.add_theme_constant_override("separation", 10)
    panel.add_child(content)

    title_label = Label.new()
    title_label.name = "Title"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 28)
    content.add_child(title_label)

    summary_label = Label.new()
    summary_label.name = "Summary"
    summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(summary_label)

    log_label = RichTextLabel.new()
    log_label.name = "CombatLog"
    log_label.bbcode_enabled = true
    log_label.scroll_following = true
    log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_label.custom_minimum_size = Vector2(0, 360)
    content.add_child(log_label)

    var actions := HBoxContainer.new()
    actions.name = "Actions"
    actions.alignment = BoxContainer.ALIGNMENT_END
    content.add_child(actions)

    skip_button = Button.new()
    skip_button.name = "Skip"
    skip_button.text = "Mostrar todo"
    skip_button.pressed.connect(_show_full_log)
    actions.add_child(skip_button)

    close_button = Button.new()
    close_button.name = "Close"
    close_button.text = "Volver a Arena"
    close_button.pressed.connect(_close_overlay)
    actions.add_child(close_button)

    finca_button = Button.new()
    finca_button.name = "Finca"
    finca_button.text = "Volver a la finca"
    finca_button.pressed.connect(_return_to_finca)
    actions.add_child(finca_button)

func _on_combat_finished(result: Dictionary) -> void:
    cached_result = result.duplicate(true)
    call_deferred("_present_result")

func _present_result() -> void:
    if overlay == null or not is_instance_valid(overlay):
        await _attach_when_ready()
    if overlay == null or not is_instance_valid(overlay):
        push_error("No se pudo presentar el resultado de Arena porque el overlay no está disponible.")
        return
    if title_label == null or summary_label == null or log_label == null:
        _cache_overlay_controls()
    if title_label == null or summary_label == null or log_label == null:
        push_error("El overlay de Arena existe pero sus controles internos no pudieron recuperarse.")
        return
    if TutorialController.has_method("suspend_for_modal"):
        TutorialController.suspend_for_modal()
    if GladiatorDossierPresenter.has_method("_close"):
        GladiatorDossierPresenter.call("_close")
    _hide_other_arena_overlays()
    if FincaHubController.has_method("open_system"):
        FincaHubController.open_system("arena")
    overlay.visible = true
    playback_token += 1
    var token := playback_token
    var victory := bool(cached_result.get("victory", false))
    var surrendered := bool(cached_result.get("surrendered", false))
    title_label.text = "VICTORIA" if victory else ("RENDICIÓN" if surrendered else "DERROTA")
    summary_label.text = "%s contra %s · %d rondas\nPremio: %d denarios · Reputación: %+d%s" % [
        str(cached_result.get("fighter", "Gladiador")),
        str(cached_result.get("enemy", "Rival")),
        int(cached_result.get("rounds", 0)),
        int(cached_result.get("reward", 0)),
        int(cached_result.get("reputation", 0)),
        "\nHerida: %s" % str(cached_result.get("injury", "")) if not str(cached_result.get("injury", "")).is_empty() else ""
    ]
    log_label.clear()
    log_label.append_text("[b]Crónica del combate[/b]\n\n")
    if skip_button != null:
        skip_button.disabled = false
    var combat_log: Array = cached_result.get("log", []) as Array
    for entry: Variant in combat_log:
        if token != playback_token or overlay == null or not overlay.visible:
            return
        log_label.append_text("%s\n" % str(entry))
        await get_tree().create_timer(0.22, true, false, true).timeout
    if skip_button != null:
        skip_button.disabled = true

func _hide_other_arena_overlays() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var preview := scene.get_node_or_null("ArenaOpponentPreview") as Control
    if preview != null:
        preview.visible = false

func _show_full_log() -> void:
    if log_label == null:
        return
    playback_token += 1
    log_label.clear()
    log_label.append_text("[b]Crónica del combate[/b]\n\n")
    for entry: Variant in cached_result.get("log", []):
        log_label.append_text("%s\n" % str(entry))
    if skip_button != null:
        skip_button.disabled = true

func _finish_result_navigation(system_id: String) -> void:
    playback_token += 1
    cached_result.clear()
    if overlay != null and is_instance_valid(overlay):
        overlay.visible = false
    if system_id == "finca":
        FincaHubController.show_finca()
    else:
        FincaHubController.open_system(system_id)
    if TutorialController.has_method("resume_after_modal"):
        TutorialController.resume_after_modal()

func _close_overlay() -> void:
    _finish_result_navigation("arena")

func _return_to_finca() -> void:
    _finish_result_navigation("finca")

func _unhandled_key_input(event: InputEvent) -> void:
    if overlay != null and is_instance_valid(overlay) and overlay.visible and event.is_action_pressed("ui_cancel"):
        _return_to_finca()
        get_viewport().set_input_as_handled()
