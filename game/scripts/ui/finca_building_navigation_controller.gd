extends Node

const MAIN_SCENE_NAME := "Main"
const BUILDING_LIST_PATH := "Margin/VBox/Tabs/Finca/BuildingList"
const BUILDING_PANEL_PATH := "Margin/VBox/Tabs/Finca/BuildingPanel"
const SYSTEM_LABELS := {
    "campana":"Abrir administración y campaña",
    "barracks":"Entrar a barracones",
    "personal":"Abrir gestión de personal",
    "forja":"Entrar a la forja",
    "arena":"Entrar a la arena"
}

var building_list: ItemList
var access_button: Button
var selected_building_id := ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_attach_when_ready")

func _attach_when_ready() -> void:
    for _attempt in range(60):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null or scene.name != MAIN_SCENE_NAME:
            continue
        building_list = scene.get_node_or_null(BUILDING_LIST_PATH) as ItemList
        var building_panel := scene.get_node_or_null(BUILDING_PANEL_PATH) as VBoxContainer
        if building_list == null or building_panel == null:
            continue
        if not building_list.item_selected.is_connected(_on_building_selected):
            building_list.item_selected.connect(_on_building_selected)
        if not building_list.item_activated.is_connected(_on_building_activated):
            building_list.item_activated.connect(_on_building_activated)
        _ensure_access_button(building_panel)
        building_list.tooltip_text = "Seleccioná una instalación para ver sus datos. Activala o usá el acceso contextual para abrir su sistema."
        _restore_selected_building()
        return
    push_error("No se pudo conectar la navegación de instalaciones de la finca.")

func _ensure_access_button(building_panel: VBoxContainer) -> void:
    access_button = building_panel.get_node_or_null("OpenBuildingSystem") as Button
    if access_button == null:
        access_button = Button.new()
        access_button.name = "OpenBuildingSystem"
        access_button.custom_minimum_size = Vector2(0, 42)
        building_panel.add_child(access_button)
    if not access_button.pressed.is_connected(_on_access_pressed):
        access_button.pressed.connect(_on_access_pressed)
    access_button.visible = false

func _restore_selected_building() -> void:
    if building_list == null or building_list.item_count == 0:
        _update_access_button()
        return
    var selected_items := building_list.get_selected_items()
    var index := selected_items[0] if not selected_items.is_empty() else 0
    _on_building_selected(index)

func _on_building_selected(index: int) -> void:
    if building_list == null or index < 0 or index >= building_list.item_count:
        selected_building_id = ""
    else:
        selected_building_id = str(building_list.get_item_metadata(index))
    _update_access_button()

func _update_access_button() -> void:
    if access_button == null:
        return
    var system_id := FincaHubController.get_building_system_id(selected_building_id)
    access_button.visible = not system_id.is_empty()
    access_button.disabled = system_id.is_empty()
    access_button.text = str(SYSTEM_LABELS.get(system_id, "Abrir sistema de la instalación"))
    if system_id.is_empty():
        access_button.tooltip_text = "Esta instalación todavía no tiene un sistema interactivo asociado en la demo."
    else:
        var data := EstateManager.get_building_data(selected_building_id)
        access_button.tooltip_text = "Abrir el sistema asociado a %s." % str(data.get("name", selected_building_id))

func _on_access_pressed() -> void:
    _open_selected_building_system()

func _on_building_activated(index: int) -> void:
    _on_building_selected(index)
    _open_selected_building_system()

func _open_selected_building_system() -> void:
    if selected_building_id.is_empty():
        return
    if not FincaHubController.open_building_system(selected_building_id):
        var data := EstateManager.get_building_data(selected_building_id)
        var building_name := str(data.get("name", selected_building_id))
        building_list.tooltip_text = "%s todavía no tiene un sistema interactivo asociado en la demo." % building_name
