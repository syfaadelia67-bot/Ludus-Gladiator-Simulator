extends Node

signal hub_opened
signal system_opened(system_id: String)
signal building_system_unavailable(building_id: String)

const MAIN_SCENE_NAME := "Main"
const TAB_PATH := "Margin/VBox/Tabs"
const VBOX_PATH := "Margin/VBox"
const SCREEN_HOST_NAME := "ScreenHost"
const ARENA_MANAGE_PATH := "Body/RosterPanel/Margin/Scroll/Content/ManageGladiators"
const ARENA_EQUIPMENT_PATH := "Body/CenterPanel/Margin/Scroll/Content/PreparationView/ActionRow/Equipment"

const SCREEN_SCENES := {
    "finca": "res://scenes/FincaScreen.tscn",
    "barracks": "res://scenes/BarracksScreen.tscn",
    "mercado": "res://scenes/MarketScreen.tscn",
    "arena": "res://scenes/ArenaScreen.tscn",
    "gladiator_dossier": "res://scenes/GladiatorDossierPanel.tscn",
    "campana": "res://scenes/CampaignPanel.tscn",
    "eventos": "res://scenes/EventsPanel.tscn",
    "rivales": "res://scenes/RivalsPanel.tscn",
    "economia": "res://scenes/EconomyPanel.tscn",
    "torneos": "res://scenes/TournamentsPanel.tscn",
    "progresion": "res://scenes/ProgressionPanel.tscn",
    "personalidad": "res://scenes/PersonalityPanel.tscn",
    "relaciones": "res://scenes/RelationshipsPanel.tscn",
    "transferencias": "res://scenes/TransfersPanel.tscn",
    "historial": "res://scenes/CombatHistoryPanel.tscn"
}

# Compatibility only. These screens still depend on fixed paths in Main.tscn,
# but the player never navigates through visible tabs.
const LEGACY_SYSTEM_TABS := {
    "personal": "Personal",
    "forja": "Forja",
    "equipamiento": "Equipamiento"
}

const BUILDING_SYSTEMS := {
    "dominus_house": "campana",
    "barracks": "barracks",
    "training_yard": "personal",
    "forge": "forja",
    "infirmary": "personal",
    "kitchen": "economia",
    "private_arena": "arena"
}

var current_system_id := "finca"
var screen_instances: Dictionary = {}

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

func prepare_scene() -> bool:
    var scene := _get_main_scene()
    if scene == null:
        return false
    var host := _ensure_screen_host(scene)
    var tabs := _get_tabs()
    if host == null or tabs == null:
        return false
    tabs.tabs_visible = false
    tabs.visible = false
    return true

func show_finca() -> bool:
    var opened := open_system("finca")
    if opened:
        hub_opened.emit()
    return opened

func open_system(system_id: String) -> bool:
    var normalized_id := system_id.strip_edges().to_lower()
    if not SCREEN_SCENES.has(normalized_id) and not LEGACY_SYSTEM_TABS.has(normalized_id):
        return false

    var scene := _get_main_scene()
    var tabs := _get_tabs()
    if scene == null or tabs == null:
        return false
    var host := _ensure_screen_host(scene)
    if host == null:
        return false

    var opened := false
    if SCREEN_SCENES.has(normalized_id):
        opened = _show_hosted_screen(normalized_id, host, tabs)
    else:
        opened = _show_legacy_screen(normalized_id, host, tabs)
    if not opened:
        return false

    current_system_id = normalized_id
    system_opened.emit(normalized_id)
    return true

func open_gladiator_dossier(person_id: String, context: Dictionary = {}, initial_tab: String = "information") -> bool:
    var person = RosterManager.get_person(person_id)
    if person == null or str(person.role) != "gladiator":
        return false
    var resolved_context := context.duplicate(true)
    if str(resolved_context.get("system_id", "")).is_empty():
        var origin_system := current_system_id
        if origin_system == "gladiator_dossier":
            origin_system = "finca"
        resolved_context["system_id"] = origin_system
    resolved_context["selected_id"] = person_id
    if not open_system("gladiator_dossier"):
        return false
    var screen := screen_instances.get("gladiator_dossier") as Control
    if screen == null or not screen.has_method("open_gladiator"):
        return false
    screen.call("open_gladiator", person_id, resolved_context, initial_tab)
    return true

func return_from_gladiator_dossier(context: Dictionary = {}) -> bool:
    var target_system := str(context.get("system_id", "finca")).strip_edges().to_lower()
    if target_system.is_empty() or target_system == "gladiator_dossier":
        target_system = "finca"
    var opened := show_finca() if target_system == "finca" else open_system(target_system)
    if not opened:
        return show_finca()
    var callback_name := str(context.get("callback", ""))
    if callback_name.is_empty() or not screen_instances.has(target_system):
        return true
    var target_screen := screen_instances.get(target_system) as Control
    if target_screen != null and target_screen.has_method(callback_name):
        target_screen.call_deferred(callback_name, context.duplicate(true))
    return true

func get_hosted_screen(system_id: String) -> Control:
    var screen := screen_instances.get(system_id.strip_edges().to_lower()) as Control
    return screen if screen != null and is_instance_valid(screen) else null

func _show_hosted_screen(system_id: String, host: Control, tabs: TabContainer) -> bool:
    var screen := screen_instances.get(system_id) as Control
    if screen == null or not is_instance_valid(screen):
        var scene_path := str(SCREEN_SCENES.get(system_id, ""))
        var packed := load(scene_path) as PackedScene
        if packed == null:
            push_error("No se pudo cargar la pantalla %s desde %s." % [system_id, scene_path])
            return false
        screen = packed.instantiate() as Control
        if screen == null:
            return false
        screen.name = "%sScreen" % system_id.capitalize()
        host.add_child(screen)
        screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        screen.grow_horizontal = Control.GROW_DIRECTION_BOTH
        screen.grow_vertical = Control.GROW_DIRECTION_BOTH
        _configure_hosted_screen(system_id, screen)
        screen_instances[system_id] = screen

    for child in host.get_children():
        if child is Control:
            var control := child as Control
            var active := control == screen
            control.visible = active
            control.mouse_filter = Control.MOUSE_FILTER_PASS if active else Control.MOUSE_FILTER_IGNORE

    tabs.visible = false
    tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
    host.visible = true
    host.mouse_filter = Control.MOUSE_FILTER_PASS
    return true

func _show_legacy_screen(system_id: String, host: Control, tabs: TabContainer) -> bool:
    var tab_name := str(LEGACY_SYSTEM_TABS.get(system_id, ""))
    var control := tabs.get_node_or_null(tab_name) as Control
    if control == null:
        return false
    var tab_index := tabs.get_tab_idx_from_control(control)
    if tab_index < 0:
        return false

    host.visible = false
    host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tabs.tabs_visible = false
    tabs.visible = true
    tabs.mouse_filter = Control.MOUSE_FILTER_PASS
    tabs.current_tab = tab_index
    return true

func _configure_hosted_screen(system_id: String, screen: Control) -> void:
    if system_id == "finca":
        for path in ["TopHUD", "MainNavigation", "BottomStatusBar"]:
            var embedded := screen.get_node_or_null(path) as Control
            if embedded != null:
                embedded.visible = false
                embedded.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var callback := Callable(screen, "_on_visibility_changed")
        if screen.visibility_changed.is_connected(callback):
            screen.visibility_changed.disconnect(callback)
    elif system_id == "arena":
        call_deferred("_configure_arena_dossier_actions", screen)

func _configure_arena_dossier_actions(screen: Control) -> void:
    if screen == null or not is_instance_valid(screen):
        return
    var manage_button := screen.get_node_or_null(ARENA_MANAGE_PATH) as Button
    var equipment_button := screen.get_node_or_null(ARENA_EQUIPMENT_PATH) as Button
    if manage_button != null:
        manage_button.text = "FICHA DEL GLADIADOR"
        manage_button.tooltip_text = "Abrir el panel individual del gladiador seleccionado."
        _replace_button_action(manage_button, Callable(self, "_open_arena_dossier").bind(screen, "information"))
    if equipment_button != null:
        equipment_button.tooltip_text = "Abrir las siete ranuras de equipamiento del gladiador seleccionado."
        _replace_button_action(equipment_button, Callable(self, "_open_arena_dossier").bind(screen, "equipment"))

func _replace_button_action(button: Button, action: Callable) -> void:
    for connection_value in button.pressed.get_connections():
        if not connection_value is Dictionary:
            continue
        var connection: Dictionary = connection_value
        var existing_value: Variant = connection.get("callable", null)
        if typeof(existing_value) != TYPE_CALLABLE:
            continue
        var existing_callable: Callable = existing_value
        if button.pressed.is_connected(existing_callable):
            button.pressed.disconnect(existing_callable)
    if not button.pressed.is_connected(action):
        button.pressed.connect(action)

func _open_arena_dossier(arena_screen: Control, initial_tab: String) -> void:
    if arena_screen == null or not is_instance_valid(arena_screen):
        return
    var person_id := str(arena_screen.get("selected_fighter_id"))
    if person_id.is_empty():
        open_system("barracks")
        return
    open_gladiator_dossier(person_id, {
        "system_id": "arena",
        "selected_id": person_id
    }, initial_tab)

func open_building_system(building_id: String) -> bool:
    var canonical_id := EstateManager.canonicalize_building_id(building_id)
    if EstateManager.is_locked(canonical_id):
        building_system_unavailable.emit(canonical_id)
        return false
    var system_id := str(BUILDING_SYSTEMS.get(canonical_id, ""))
    if system_id.is_empty():
        building_system_unavailable.emit(canonical_id)
        return false
    return open_system(system_id)

func get_building_system_id(building_id: String) -> String:
    var canonical_id := EstateManager.canonicalize_building_id(building_id)
    if EstateManager.is_locked(canonical_id):
        return ""
    return str(BUILDING_SYSTEMS.get(canonical_id, ""))

func get_current_system_id() -> String:
    return current_system_id

func _ensure_screen_host(scene: Control) -> Control:
    var vbox := scene.get_node_or_null(VBOX_PATH) as VBoxContainer
    var tabs := _get_tabs()
    if vbox == null or tabs == null:
        return null
    var host := vbox.get_node_or_null(SCREEN_HOST_NAME) as Control
    if host == null:
        host = Control.new()
        host.name = SCREEN_HOST_NAME
        host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        host.size_flags_vertical = Control.SIZE_EXPAND_FILL
        host.clip_contents = true
        vbox.add_child(host)
        vbox.move_child(host, tabs.get_index())
    return host

func _get_main_scene() -> Control:
    if not is_inside_tree():
        return null
    var tree := get_tree()
    if tree == null:
        return null
    var scene := tree.current_scene as Control
    if scene == null or scene.name != MAIN_SCENE_NAME:
        return null
    return scene

func _get_tabs() -> TabContainer:
    var scene := _get_main_scene()
    if scene == null:
        return null
    return scene.get_node_or_null(TAB_PATH) as TabContainer
