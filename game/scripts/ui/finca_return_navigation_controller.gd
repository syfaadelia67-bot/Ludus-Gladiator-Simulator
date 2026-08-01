extends Node

const MAIN_SCENE_NAME := "Main"
const TOP_BUTTONS_PATH := "Margin/VBox/TopButtons"
const TABS_PATH := "Margin/VBox/Tabs"

var return_button: Button
var tabs: TabContainer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    for _attempt in range(60):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null or scene.name != MAIN_SCENE_NAME:
            continue
        var top_buttons := scene.get_node_or_null(TOP_BUTTONS_PATH) as HBoxContainer
        tabs = scene.get_node_or_null(TABS_PATH) as TabContainer
        if top_buttons == null or tabs == null:
            continue
        return_button = top_buttons.get_node_or_null("ReturnToFinca") as Button
        if return_button == null:
            return_button = Button.new()
            return_button.name = "ReturnToFinca"
            return_button.text = "Volver a la finca"
            return_button.tooltip_text = "Regresa al hub principal del ludus."
            return_button.custom_minimum_size = Vector2(150, 0)
            top_buttons.add_child(return_button)
            top_buttons.move_child(return_button, 0)
        if not return_button.pressed.is_connected(_on_return_pressed):
            return_button.pressed.connect(_on_return_pressed)
        if not tabs.tab_changed.is_connected(_on_tab_changed):
            tabs.tab_changed.connect(_on_tab_changed)
        FincaHubController.system_opened.connect(_on_system_opened)
        _refresh_visibility()
        return
    push_error("No se pudo montar el acceso permanente para volver a la finca.")

func _on_return_pressed() -> void:
    FincaHubController.show_finca()

func _on_tab_changed(_tab: int) -> void:
    _refresh_visibility()

func _on_system_opened(_system_id: String) -> void:
    _refresh_visibility()

func _refresh_visibility() -> void:
    if return_button == null or not is_instance_valid(return_button):
        return
    return_button.visible = FincaHubController.get_current_system_id() != "finca"
