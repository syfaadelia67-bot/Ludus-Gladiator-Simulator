extends Node

const MAIN_SCENE_NAME := "Main"
const BUILDING_LIST_PATH := "Margin/VBox/Tabs/Finca/BuildingList"

var building_list: ItemList

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
        if building_list == null:
            continue
        if not building_list.item_activated.is_connected(_on_building_activated):
            building_list.item_activated.connect(_on_building_activated)
        building_list.tooltip_text = "Seleccioná una instalación para ver sus datos. Activala para abrir su sistema asociado."
        return
    push_error("No se pudo conectar la navegación de instalaciones de la finca.")

func _on_building_activated(index: int) -> void:
    if building_list == null or index < 0 or index >= building_list.item_count:
        return
    var building_id := str(building_list.get_item_metadata(index))
    if building_id.is_empty():
        return
    if not FincaHubController.open_building_system(building_id):
        var data := EstateManager.get_building_data(building_id)
        var building_name := str(data.get("name", building_id))
        building_list.tooltip_text = "%s todavía no tiene un sistema interactivo asociado en la demo." % building_name
