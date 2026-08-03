extends Node

const MAIN_SCENE_NAME := "Main"
const TOP_BUTTONS_PATH := "Margin/VBox/TopButtons"
const TABS_PATH := "Margin/VBox/Tabs"
const ARENA_SETUP_PATH := "Margin/VBox/Tabs/Arena/Setup"

var return_button: Button
var arena_return_button: Button
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
        var arena_setup := scene.get_node_or_null(ARENA_SETUP_PATH) as HBoxContainer
        tabs = scene.get_node_or_null(TABS_PATH) as TabContainer
        if top_buttons == null or arena_setup == null or tabs == null:
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

        arena_return_button = arena_setup.get_node_or_null("ArenaReturnToFinca") as Button
        if arena_return_button == null:
            arena_return_button = Button.new()
            arena_return_button.name = "ArenaReturnToFinca"
            arena_return_button.text = "Volver a la finca"
            arena_return_button.tooltip_text = "Salir de Arena y regresar al centro del ludus."
            arena_return_button.custom_minimum_size = Vector2(150, 0)
            arena_setup.add_child(arena_return_button)
        if not arena_return_button.pressed.is_connected(_on_return_pressed):
            arena_return_button.pressed.connect(_on_return_pressed)

        if not tabs.tab_changed.is_connected(_on_tab_changed):
            tabs.tab_changed.connect(_on_tab_changed)
        if not FincaHubController.system_opened.is_connected(_on_system_opened):
            FincaHubController.system_opened.connect(_on_system_opened)
        _refresh_visibility()
        return
    push_error("No se pudo montar el acceso permanente para volver a la finca.")

func _on_return_pressed() -> void:
    _close_blocking_overlays()
    FincaHubController.show_finca()

func _close_blocking_overlays() -> void:
    if GladiatorDossierPresenter.has_method("_close"):
        GladiatorDossierPresenter.call("_close")
    var scene := get_tree().current_scene
    if scene == null:
        return
    for overlay_name in ["ArenaCombatResult", "ArenaOpponentPreview"]:
        var overlay := scene.get_node_or_null(overlay_name) as Control
        if overlay != null:
            overlay.visible = false

func _on_tab_changed(_tab: int) -> void:
    _refresh_visibility()

func _on_system_opened(_system_id: String) -> void:
    _refresh_visibility()

func _refresh_visibility() -> void:
    var current_system := FincaHubController.get_current_system_id()
    if return_button != null and is_instance_valid(return_button):
        return_button.visible = current_system != "finca"
    if arena_return_button != null and is_instance_valid(arena_return_button):
        arena_return_button.visible = current_system == "arena"
