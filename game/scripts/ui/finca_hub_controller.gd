extends Node

signal hub_opened
signal system_opened(system_id: String)
signal building_system_unavailable(building_id: String)

const MAIN_SCENE_NAME := "Main"
const TAB_PATH := "Margin/VBox/Tabs"
const SYSTEM_TABS := {
    "finca": "Finca",
    "personal": "Personal",
    "mercado": "Mercado",
    "forja": "Forja",
    "equipamiento": "Equipamiento",
    "eventos": "Eventos",
    "rivales": "Rivales",
    "economia": "Economía",
    "torneos": "Torneos",
    "progresion": "Progresión",
    "arena": "Arena",
    "campana": "Campaña"
}
const BUILDING_SYSTEMS := {
    "dominus_house": "campana",
    "barracks": "personal",
    "training_yard": "personal",
    "forge": "forja",
    "private_arena": "arena"
}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    SaveManager.load_completed.connect(_on_campaign_entered)
    NewCampaignCoordinator.campaign_reset_completed.connect(_on_campaign_entered)

func _on_campaign_entered(_unused = null) -> void:
    call_deferred("_open_finca_when_ready")

func _open_finca_when_ready() -> void:
    for _attempt in range(30):
        if show_finca():
            return
        await get_tree().process_frame

func show_finca() -> bool:
    var opened := open_system("finca")
    if opened:
        hub_opened.emit()
    return opened

func open_system(system_id: String) -> bool:
    var normalized_id := system_id.strip_edges().to_lower()
    if not SYSTEM_TABS.has(normalized_id):
        return false
    var tabs := _get_tabs()
    if tabs == null:
        return false
    var tab_name := str(SYSTEM_TABS[normalized_id])
    var control := tabs.get_node_or_null(tab_name) as Control
    if control == null:
        return false
    var tab_index := tabs.get_tab_idx_from_control(control)
    if tab_index < 0:
        return false
    tabs.current_tab = tab_index
    system_opened.emit(normalized_id)
    return true

func open_building_system(building_id: String) -> bool:
    var canonical_id := EstateManager.canonicalize_building_id(building_id)
    var system_id := str(BUILDING_SYSTEMS.get(canonical_id, ""))
    if system_id.is_empty():
        building_system_unavailable.emit(canonical_id)
        return false
    return open_system(system_id)

func get_building_system_id(building_id: String) -> String:
    var canonical_id := EstateManager.canonicalize_building_id(building_id)
    return str(BUILDING_SYSTEMS.get(canonical_id, ""))

func get_current_system_id() -> String:
    var tabs := _get_tabs()
    if tabs == null or tabs.current_tab < 0:
        return ""
    var current_control := tabs.get_tab_control(tabs.current_tab)
    if current_control == null:
        return ""
    for system_id in SYSTEM_TABS.keys():
        if str(SYSTEM_TABS[system_id]) == current_control.name:
            return str(system_id)
    return ""

func _get_tabs() -> TabContainer:
    if not is_inside_tree():
        return null
    var tree := get_tree()
    if tree == null:
        return null
    var scene := tree.current_scene
    if scene == null or scene.name != MAIN_SCENE_NAME:
        return null
    return scene.get_node_or_null(TAB_PATH) as TabContainer
