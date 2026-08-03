extends Node

const MAIN_SCENE_NAME := "Main"
const ATTACH_ATTEMPTS := 180

const PANEL_TEXTURE_PATH := "res://assets/placeholders/pack_000/ui/panels/ui_panel_brown.png"
const PRIMARY_BUTTON_TEXTURE_PATH := "res://assets/placeholders/pack_000/ui/buttons/ui_button_primary.png"
const SECONDARY_BUTTON_TEXTURE_PATH := "res://assets/placeholders/pack_000/ui/buttons/ui_button_secondary.png"

var _applied_scene_id: int = 0
var _hud_theme: Theme

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().tree_changed.connect(_on_tree_changed)
    call_deferred("_apply_when_ready")

func _on_tree_changed() -> void:
    var scene := get_tree().current_scene
    if scene == null or scene.name != MAIN_SCENE_NAME:
        return
    if scene.get_instance_id() != _applied_scene_id:
        call_deferred("_apply_when_ready")

func _apply_when_ready() -> void:
    for _attempt in range(ATTACH_ATTEMPTS):
        await get_tree().process_frame
        var scene := get_tree().current_scene as Control
        if scene == null or scene.name != MAIN_SCENE_NAME:
            continue
        if scene.get_instance_id() == _applied_scene_id:
            return
        _hud_theme = _build_theme()
        if _hud_theme == null:
            push_error("No se pudo construir la piel visual del HUD.")
            return
        scene.theme = _hud_theme
        _style_main_scene(scene)
        _applied_scene_id = scene.get_instance_id()
        return
    push_error("No se pudo aplicar la piel visual del HUD a la escena Main.")

func _build_theme() -> Theme:
    var panel_texture := _load_texture(PANEL_TEXTURE_PATH)
    var primary_texture := _load_texture(PRIMARY_BUTTON_TEXTURE_PATH)
    var secondary_texture := _load_texture(SECONDARY_BUTTON_TEXTURE_PATH)
    if panel_texture == null or primary_texture == null or secondary_texture == null:
        return null

    var theme := Theme.new()
    theme.default_font_size = 17

    var panel_style := _texture_style(panel_texture, 14.0, 12.0)
    var primary_style := _texture_style(primary_texture, 15.0, 9.0)
    var secondary_style := _texture_style(secondary_texture, 12.0, 8.0)
    var focus_style := _flat_style(Color(0.72, 0.52, 0.23, 0.38), Color(0.94, 0.72, 0.34, 0.9), 2)
    var list_selected := _flat_style(Color(0.42, 0.22, 0.08, 0.92), Color(0.82, 0.58, 0.24, 0.9), 1)
    var bar_background := _flat_style(Color(0.08, 0.07, 0.06, 0.92), Color(0.34, 0.27, 0.19, 1.0), 1)
    var bar_fill := _flat_style(Color(0.55, 0.25, 0.08, 0.95), Color(0.88, 0.61, 0.23, 1.0), 1)

    for type_name in ["Panel", "PanelContainer"]:
        theme.set_stylebox("panel", type_name, panel_style)

    for type_name in ["Button", "OptionButton", "MenuButton"]:
        theme.set_stylebox("normal", type_name, secondary_style)
        theme.set_stylebox("hover", type_name, primary_style)
        theme.set_stylebox("pressed", type_name, primary_style)
        theme.set_stylebox("focus", type_name, focus_style)
        theme.set_stylebox("disabled", type_name, secondary_style)
        theme.set_color("font_color", type_name, Color(0.96, 0.91, 0.82, 1.0))
        theme.set_color("font_hover_color", type_name, Color.WHITE)
        theme.set_color("font_pressed_color", type_name, Color.WHITE)
        theme.set_color("font_disabled_color", type_name, Color(0.55, 0.52, 0.48, 1.0))
        theme.set_constant("outline_size", type_name, 1)

    theme.set_stylebox("panel", "TabContainer", panel_style)
    theme.set_stylebox("tab_unselected", "TabBar", secondary_style)
    theme.set_stylebox("tab_selected", "TabBar", primary_style)
    theme.set_stylebox("tab_hovered", "TabBar", primary_style)
    theme.set_color("font_unselected_color", "TabBar", Color(0.77, 0.72, 0.64, 1.0))
    theme.set_color("font_selected_color", "TabBar", Color.WHITE)

    for type_name in ["ItemList", "Tree", "LineEdit", "TextEdit", "RichTextLabel"]:
        theme.set_stylebox("panel", type_name, panel_style)
        theme.set_stylebox("normal", type_name, panel_style)
        theme.set_stylebox("focus", type_name, focus_style)

    theme.set_stylebox("selected", "ItemList", list_selected)
    theme.set_stylebox("selected_focus", "ItemList", list_selected)
    theme.set_stylebox("background", "ProgressBar", bar_background)
    theme.set_stylebox("fill", "ProgressBar", bar_fill)
    theme.set_color("font_color", "Label", Color(0.94, 0.90, 0.83, 1.0))
    theme.set_color("default_color", "RichTextLabel", Color(0.92, 0.88, 0.81, 1.0))
    theme.set_constant("separation", "VBoxContainer", 9)
    theme.set_constant("separation", "HBoxContainer", 9)
    return theme

func _style_main_scene(scene: Control) -> void:
    var background := scene.get_node_or_null("Background") as ColorRect
    if background != null:
        background.color = Color(0.055, 0.045, 0.035, 1.0)

    var title := scene.get_node_or_null("Margin/VBox/Title") as Label
    if title != null:
        title.add_theme_font_size_override("font_size", 30)
        title.add_theme_color_override("font_color", Color(0.95, 0.76, 0.38, 1.0))
        title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
        title.add_theme_constant_override("shadow_offset_x", 2)
        title.add_theme_constant_override("shadow_offset_y", 2)

    var top_buttons := scene.get_node_or_null("Margin/VBox/TopButtons") as HBoxContainer
    if top_buttons != null:
        top_buttons.add_theme_constant_override("separation", 10)

    var tabs := scene.get_node_or_null("Margin/VBox/Tabs") as TabContainer
    if tabs != null:
        tabs.add_theme_constant_override("side_margin", 10)

    for node in scene.find_children("*", "Button", true, false):
        var button := node as Button
        if button == null:
            continue
        button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 38.0)
        button.focus_mode = Control.FOCUS_ALL

    for node in scene.find_children("*", "ProgressBar", true, false):
        var bar := node as ProgressBar
        if bar != null:
            bar.custom_minimum_size.y = maxf(bar.custom_minimum_size.y, 12.0)

func _texture_style(texture: Texture2D, horizontal_margin: float, vertical_margin: float) -> StyleBoxTexture:
    var style := StyleBoxTexture.new()
    style.texture = texture
    style.texture_margin_left = horizontal_margin
    style.texture_margin_right = horizontal_margin
    style.texture_margin_top = vertical_margin
    style.texture_margin_bottom = vertical_margin
    style.content_margin_left = horizontal_margin
    style.content_margin_right = horizontal_margin
    style.content_margin_top = vertical_margin * 0.7
    style.content_margin_bottom = vertical_margin * 0.7
    return style

func _flat_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(border_width)
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    return style

func _load_texture(path: String) -> Texture2D:
    if not ResourceLoader.exists(path):
        push_warning("No se encontró el asset visual del HUD: %s" % path)
        return null
    return load(path) as Texture2D
