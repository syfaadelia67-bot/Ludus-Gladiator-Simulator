extends Node

const MAIN_SCENE_NAME := "Main"

var overlay: ColorRect
var title_label: Label
var summary_label: Label
var log_label: RichTextLabel
var close_button: Button
var finca_button: Button
var skip_button: Button
var playback_token: int = 0
var cached_result: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    CombatManager.combat_finished.connect(_on_combat_finished)
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    for _attempt in range(60):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null or scene.name != MAIN_SCENE_NAME:
            continue
        _build_overlay(scene)
        return

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
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 96)
    margin.add_theme_constant_override("margin_top", 54)
    margin.add_theme_constant_override("margin_right", 96)
    margin.add_theme_constant_override("margin_bottom", 54)
    overlay.add_child(margin)

    var panel := PanelContainer.new()
    margin.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    panel.add_child(content)

    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 28)
    content.add_child(title_label)

    summary_label = Label.new()
    summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(summary_label)

    log_label = RichTextLabel.new()
    log_label.bbcode_enabled = true
    log_label.scroll_following = true
    log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_label.custom_minimum_size = Vector2(0, 360)
    content.add_child(log_label)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_END
    content.add_child(actions)

    skip_button = Button.new()
    skip_button.text = "Mostrar todo"
    skip_button.pressed.connect(_show_full_log)
    actions.add_child(skip_button)

    close_button = Button.new()
    close_button.text = "Volver a Arena"
    close_button.pressed.connect(_close_overlay)
    actions.add_child(close_button)

    finca_button = Button.new()
    finca_button.text = "Volver a la finca"
    finca_button.pressed.connect(_return_to_finca)
    actions.add_child(finca_button)

func _on_combat_finished(result: Dictionary) -> void:
    cached_result = result.duplicate(true)
    call_deferred("_present_result")

func _present_result() -> void:
    if overlay == null or not is_instance_valid(overlay):
        return
    GladiatorDossierPresenter._close()
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
    skip_button.disabled = false
    var combat_log: Array = cached_result.get("log", []) as Array
    for entry: Variant in combat_log:
        if token != playback_token or overlay == null or not overlay.visible:
            return
        log_label.append_text("%s\n" % str(entry))
        await get_tree().create_timer(0.22, true, false, true).timeout
    skip_button.disabled = true

func _show_full_log() -> void:
    playback_token += 1
    log_label.clear()
    log_label.append_text("[b]Crónica del combate[/b]\n\n")
    for entry: Variant in cached_result.get("log", []):
        log_label.append_text("%s\n" % str(entry))
    skip_button.disabled = true

func _close_overlay() -> void:
    playback_token += 1
    if overlay != null:
        overlay.visible = false
    FincaHubController.open_system("arena")

func _return_to_finca() -> void:
    playback_token += 1
    if overlay != null:
        overlay.visible = false
    FincaHubController.show_finca()

func _unhandled_key_input(event: InputEvent) -> void:
    if overlay != null and overlay.visible and event.is_action_pressed("ui_cancel"):
        _close_overlay()
        get_viewport().set_input_as_handled()
