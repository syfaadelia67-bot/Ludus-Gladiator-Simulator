extends Node

const MAIN_SCENE_NAME := "Main"
const SAVE_COMPATIBILITY_INSPECTOR = preload("res://scripts/core/save_compatibility_inspector.gd")

var overlay: ColorRect
var card: VBoxContainer
var status_label: Label
var name_input: LineEdit
var title_selector: OptionButton
var origin_selector: OptionButton
var origin_details: RichTextLabel
var continue_button: Button
var language_selector: OptionButton
var pseudolocalization_toggle: CheckButton
var save_inspection: Dictionary = {}
var active_view := "main"
var owner_draft: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    LocalizationManager.locale_changed.connect(_on_locale_changed)
    LocalizationManager.pseudolocalization_changed.connect(_on_pseudolocalization_changed)
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
    var existing := scene.get_node_or_null("StartScreen") as ColorRect
    if existing != null:
        overlay = existing
        card = existing.find_child("StartMenuCard", true, false) as VBoxContainer
        if card != null:
            overlay.visible = true
            _show_main_menu()
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
    panel.custom_minimum_size = Vector2(720, 650)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 32)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_right", 32)
    margin.add_theme_constant_override("margin_bottom", 28)
    panel.add_child(margin)

    card = VBoxContainer.new()
    card.name = "StartMenuCard"
    card.add_theme_constant_override("separation", 14)
    margin.add_child(card)
    _show_main_menu()

func show_main_menu() -> void:
    var scene := get_tree().current_scene
    if scene == null or scene.name != MAIN_SCENE_NAME:
        return
    if SaveManager.save_game():
        pass
    if overlay == null or not is_instance_valid(overlay):
        _build_title_screen(scene)
    else:
        overlay.visible = true
        _show_main_menu()

func _enter_campaign() -> void:
    if overlay != null and is_instance_valid(overlay):
        overlay.visible = false

func _clear_card() -> void:
    for child in card.get_children():
        card.remove_child(child)
        child.queue_free()

func _t(key: String, values: Dictionary = {}) -> String:
    return LocalizationManager.translate_key(key, values)

func _title(text_value: String, size: int = 30) -> Label:
    var label := Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.theme_type_variation = &"TitleLabel" if size >= 36 else &"HeadingLabel"
    return label

func _button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 50)
    button.pressed.connect(callback)
    return button

func _inspect_save() -> Dictionary:
    var inspector = SAVE_COMPATIBILITY_INSPECTOR.new()
    var result: Dictionary = inspector.inspect()
    inspector.free()
    return result

func _show_main_menu() -> void:
    active_view = "main"
    _clear_card()
    card.add_child(_title(_t("START_BRAND"), 42))
    card.add_child(_title(_t("START_GAME_TITLE"), 24))

    var subtitle := Label.new()
    subtitle.text = _t("START_SUBTITLE")
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.theme_type_variation = &"BodyLabel"
    card.add_child(subtitle)

    save_inspection = _inspect_save()
    var metadata: Dictionary = save_inspection.get("metadata", {})
    var campaign_over := bool(metadata.get("campaign_over", false))
    continue_button = _button(_t("START_VIEW_FINAL_RESULT") if campaign_over else _t("START_CONTINUE_CAMPAIGN"), _continue_campaign)
    continue_button.disabled = not bool(save_inspection.get("loadable", false))
    continue_button.tooltip_text = str(save_inspection.get("message", _t("START_NO_SAVE")))
    card.add_child(continue_button)
    card.add_child(_button(_t("START_NEW_CAMPAIGN"), func() -> void: _show_owner_creation(true)))
    card.add_child(_button(_t("START_EXIT"), func() -> void: get_tree().quit()))

    _add_language_controls()

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.custom_minimum_size = Vector2(0, 120)
    status_label.theme_type_variation = &"CompactLabel"
    var inspection_message := str(save_inspection.get("message", _t("START_NO_CAMPAIGN")))
    status_label.text = "%s\n%s" % [_format_save_summary(metadata), inspection_message] if not metadata.is_empty() else inspection_message
    card.add_child(status_label)

func _add_language_controls() -> void:
    var separator := HSeparator.new()
    card.add_child(separator)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    card.add_child(row)

    var label := Label.new()
    label.text = _t("LANGUAGE_LABEL")
    label.custom_minimum_size = Vector2(180, 0)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.theme_type_variation = &"CompactLabel"
    row.add_child(label)

    language_selector = OptionButton.new()
    language_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var preferences := LocalizationManager.get_locale_options()
    var selected_index := 0
    for index in range(preferences.size()):
        var preference := str(preferences[index])
        language_selector.add_item(LocalizationManager.get_locale_label(preference))
        language_selector.set_item_metadata(index, preference)
        if preference == LocalizationManager.get_locale_preference():
            selected_index = index
    language_selector.select(selected_index)
    language_selector.item_selected.connect(_on_language_selected)
    row.add_child(language_selector)

    if OS.is_debug_build():
        pseudolocalization_toggle = CheckButton.new()
        pseudolocalization_toggle.text = _t("LOCALIZATION_PSEUDO_LABEL")
        pseudolocalization_toggle.tooltip_text = _t("LOCALIZATION_PSEUDO_TOOLTIP")
        pseudolocalization_toggle.button_pressed = LocalizationManager.is_pseudolocalization_enabled()
        pseudolocalization_toggle.toggled.connect(_on_pseudolocalization_toggled)
        card.add_child(pseudolocalization_toggle)

func _on_language_selected(index: int) -> void:
    if language_selector == null or index < 0 or index >= language_selector.item_count:
        return
    var preference := str(language_selector.get_item_metadata(index))
    LocalizationManager.set_locale_preference(preference)

func _on_pseudolocalization_toggled(enabled: bool) -> void:
    LocalizationManager.set_pseudolocalization_enabled(enabled)

func _on_locale_changed(_locale: String) -> void:
    if card == null or not is_instance_valid(card):
        return
    if active_view == "owner_creation":
        _capture_owner_draft()
        _show_owner_creation(false)
    else:
        _show_main_menu()

func _on_pseudolocalization_changed(_enabled: bool) -> void:
    if card != null and is_instance_valid(card):
        _on_locale_changed(LocalizationManager.get_active_locale())

func _format_save_summary(metadata: Dictionary) -> String:
    var week := maxi(1, int(metadata.get("week", metadata.get("day", 1))))
    var owner_name := str(metadata.get("owner_name", "")).strip_edges()
    var owner_title := _owner_title_name(str(metadata.get("owner_title", "dominus")))
    var owner_line := "%s %s" % [owner_title, owner_name] if not owner_name.is_empty() else owner_title
    if bool(metadata.get("campaign_over", false)):
        return _t("START_CAMPAIGN_FINISHED_SUMMARY", {
            "owner": owner_line,
            "result": _t("START_RESULT_VICTORY") if bool(metadata.get("victory", false)) else _t("START_RESULT_DEFEAT"),
            "week": mini(16, week),
            "wins": maxi(0, int(metadata.get("wins", 0))),
            "losses": maxi(0, int(metadata.get("losses", 0)))
        })
    return _t("START_ACTIVE_CAMPAIGN_SUMMARY", {
        "owner": owner_line,
        "week": week,
        "chapter": _chapter_number_for_week(week),
        "chapter_name": _chapter_name_for_week(week),
        "battle": _battle_name_for_week(week)
    })

func _owner_title_name(title_id: String) -> String:
    return _t("OWNER_TITLE_DOMINA") if title_id.to_lower() == "domina" else _t("OWNER_TITLE_DOMINUS")

func _chapter_number_for_week(week: int) -> int:
    if week >= 12:
        return 3
    if week >= 6:
        return 2
    return 1

func _chapter_name_for_week(week: int) -> String:
    if week >= 12:
        return _t("CHAPTER_3_NAME")
    if week >= 6:
        return _t("CHAPTER_2_NAME")
    return _t("CHAPTER_1_NAME")

func _battle_name_for_week(week: int) -> String:
    if week == 16:
        return _t("BATTLE_DEMO_FINAL")
    if week % 4 == 0:
        return _t("BATTLE_OFFICIAL_TOURNAMENT")
    if week % 3 == 0:
        return _t("BATTLE_BEAST_HUNT")
    if week % 2 == 0:
        return _t("BATTLE_UNDERGROUND")
    return _t("BATTLE_WEEKLY_EXHIBITION")

func _continue_campaign() -> void:
    save_inspection = _inspect_save()
    if not bool(save_inspection.get("loadable", false)):
        status_label.text = str(save_inspection.get("message", _t("START_LOAD_FAILED")))
        continue_button.disabled = true
        return
    continue_button.disabled = true
    status_label.text = _t("START_LOADING")
    if SaveManager.load_game():
        _enter_campaign()
    else:
        save_inspection = _inspect_save()
        status_label.text = str(save_inspection.get("message", _t("START_LOAD_FAILED")))
        continue_button.disabled = not bool(save_inspection.get("loadable", false))

func _show_owner_creation(reset_draft: bool = false) -> void:
    active_view = "owner_creation"
    if reset_draft:
        owner_draft.clear()
    _clear_card()
    card.add_child(_title(_t("START_NEW_CAMPAIGN_TITLE"), 30))

    var explanation := Label.new()
    explanation.text = _t("START_OWNER_EXPLANATION")
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    explanation.theme_type_variation = &"BodyLabel"
    card.add_child(explanation)

    title_selector = OptionButton.new()
    title_selector.add_item(_t("OWNER_TITLE_DOMINUS"))
    title_selector.set_item_metadata(0, "dominus")
    title_selector.add_item(_t("OWNER_TITLE_DOMINA"))
    title_selector.set_item_metadata(1, "domina")
    card.add_child(title_selector)

    name_input = LineEdit.new()
    name_input.placeholder_text = _t("START_OWNER_NAME_PLACEHOLDER")
    name_input.max_length = 32
    card.add_child(name_input)

    origin_selector = OptionButton.new()
    for origin_id in LudusOwnerManager.get_origin_ids():
        var origin := LudusOwnerManager.get_origin(origin_id)
        origin_selector.add_item(str(origin.get("name", origin_id.capitalize())))
        origin_selector.set_item_metadata(origin_selector.item_count - 1, origin_id)
    origin_selector.item_selected.connect(func(_index: int): _refresh_origin_details())
    card.add_child(origin_selector)

    _restore_owner_draft()

    origin_details = RichTextLabel.new()
    origin_details.bbcode_enabled = true
    origin_details.fit_content = true
    origin_details.custom_minimum_size = Vector2(0, 170)
    card.add_child(origin_details)
    _refresh_origin_details()

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card.add_child(status_label)

    _add_language_controls()
    card.add_child(_button(_t("START_BEGIN_CAMPAIGN"), _start_new_campaign))
    card.add_child(_button(_t("COMMON_BACK"), _show_main_menu))

func _capture_owner_draft() -> void:
    if name_input != null and is_instance_valid(name_input):
        owner_draft["name"] = name_input.text
    if title_selector != null and is_instance_valid(title_selector) and title_selector.selected >= 0:
        owner_draft["title_id"] = str(title_selector.get_item_metadata(title_selector.selected))
    if origin_selector != null and is_instance_valid(origin_selector) and origin_selector.selected >= 0:
        owner_draft["origin_id"] = str(origin_selector.get_item_metadata(origin_selector.selected))

func _restore_owner_draft() -> void:
    if name_input != null:
        name_input.text = str(owner_draft.get("name", ""))
    var title_id := str(owner_draft.get("title_id", "dominus"))
    if title_selector != null:
        for index in range(title_selector.item_count):
            if str(title_selector.get_item_metadata(index)) == title_id:
                title_selector.select(index)
                break
    var origin_id := str(owner_draft.get("origin_id", ""))
    if origin_selector != null and not origin_id.is_empty():
        for index in range(origin_selector.item_count):
            if str(origin_selector.get_item_metadata(index)) == origin_id:
                origin_selector.select(index)
                break

func _refresh_origin_details() -> void:
    if origin_details == null or origin_selector == null or origin_selector.selected < 0:
        return
    var origin_id := str(origin_selector.get_item_metadata(origin_selector.selected))
    var origin := LudusOwnerManager.get_origin(origin_id)
    var bonus_lines: Array[String] = []
    var bonuses: Dictionary = origin.get("bonuses", {})
    var labels := {
        "starting_denarii":"START_BONUS_DENARII",
        "starting_food":"START_BONUS_FOOD",
        "starting_ore":"START_BONUS_ORE",
        "starting_reputation":"START_BONUS_REPUTATION",
        "starting_loyalty":"START_BONUS_LOYALTY",
        "starting_morale":"START_BONUS_MORALE"
    }
    for key in labels.keys():
        var value := int(bonuses.get(key, 0))
        if value != 0:
            bonus_lines.append("• %s: %+d" % [_t(str(labels[key])), value])
    var experience_multiplier := float(bonuses.get("gladiator_experience_multiplier", 1.0))
    if experience_multiplier > 1.0:
        bonus_lines.append("• %s: +%d%%" % [_t("START_BONUS_GLADIATOR_EXPERIENCE"), int(round((experience_multiplier - 1.0) * 100.0))])
    origin_details.text = "[b]%s[/b]\n%s\n\n[b]%s[/b]\n%s" % [
        origin.get("name", _t("START_ORIGIN_FALLBACK")),
        origin.get("description", ""),
        _t("START_BONUSES"),
        "\n".join(bonus_lines) if not bonus_lines.is_empty() else _t("START_NO_BONUSES")
    ]

func _start_new_campaign() -> void:
    if origin_selector.selected < 0:
        status_label.text = _t("START_SELECT_ORIGIN")
        return
    var title_id := str(title_selector.get_item_metadata(title_selector.selected))
    var origin_id := str(origin_selector.get_item_metadata(origin_selector.selected))
    var display_name := name_input.text.strip_edges()
    if display_name.length() < 2:
        status_label.text = _t("START_NAME_MIN_LENGTH")
        return
    if not NewCampaignCoordinator.reset_campaign_state():
        status_label.text = _t("START_RESET_FAILED")
        return
    if not LudusOwnerManager.configure_owner(title_id, display_name, origin_id):
        status_label.text = _t("START_OWNER_CONFIG_FAILED")
        return
    if not SaveManager.save_game():
        status_label.text = _t("START_SAVE_FAILED")
        return
    owner_draft.clear()
    _enter_campaign()
