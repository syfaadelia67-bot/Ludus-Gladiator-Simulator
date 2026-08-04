extends Node

const PANELS := [
    {"name":"Rivales", "scene":preload("res://scenes/RivalsPanel.tscn")},
    {"name":"Eventos", "scene":preload("res://scenes/EventsPanel.tscn")},
    {"name":"Economía", "scene":preload("res://scenes/EconomyPanel.tscn")},
    {"name":"Torneos", "scene":preload("res://scenes/TournamentsPanel.tscn")},
    {"name":"Campaña", "scene":preload("res://scenes/CampaignPanel.tscn")},
    {"name":"Progresión", "scene":preload("res://scenes/ProgressionPanel.tscn")},
    {"name":"Personalidad", "scene":preload("res://scenes/PersonalityPanel.tscn")},
    {"name":"Relaciones", "scene":preload("res://scenes/RelationshipsPanel.tscn")},
    {"name":"Transferencias", "scene":preload("res://scenes/TransfersPanel.tscn")},
    {"name":"Historial", "scene":preload("res://scenes/CombatHistoryPanel.tscn")}
]

const FINCA_SCREEN = preload("res://scenes/FincaScreen.tscn")
const ARENA_SCREEN = preload("res://scenes/ArenaScreen.tscn")
const UNIFIED_HUD = preload("res://scenes/UnifiedHudShell.tscn")
const MAX_ATTACH_ATTEMPTS := 30

var main_root: Control
var main_tabs: TabContainer

func _ready() -> void:
    _attach_when_ready()

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and FincaHubController.get_current_system_id() == "arena":
        _go_to_finca()
        get_viewport().set_input_as_handled()

func _attach_when_ready() -> void:
    for _attempt in range(MAX_ATTACH_ATTEMPTS):
        await get_tree().process_frame
        var root := get_tree().current_scene as Control
        if root == null or not root.is_inside_tree():
            continue
        var tabs := root.find_child("Tabs", true, false) as TabContainer
        if tabs == null:
            continue
        main_root = root
        main_tabs = tabs
        _attach_panels(tabs)
        _attach_finca_screen(tabs)
        _attach_arena_screen(tabs)
        _attach_unified_hud(root)
        _enforce_unified_layout()
        if not tabs.tab_changed.is_connected(_on_tab_changed):
            tabs.tab_changed.connect(_on_tab_changed)
        call_deferred("_select_finca_as_primary_view", tabs)
        return
    push_error("No se encontró el TabContainer principal llamado Tabs después de esperar la escena activa.")

func _attach_panels(tabs: TabContainer) -> void:
    for panel_data in PANELS:
        var panel_name := str(panel_data.get("name", ""))
        if panel_name.is_empty() or tabs.get_node_or_null(NodePath(panel_name)) != null:
            continue
        var packed_scene: PackedScene = panel_data.get("scene")
        if packed_scene == null:
            push_error("No se pudo cargar el panel %s." % panel_name)
            continue
        var panel := packed_scene.instantiate()
        panel.name = panel_name
        tabs.add_child(panel)

func _attach_finca_screen(tabs: TabContainer) -> void:
    var finca := tabs.get_node_or_null("Finca") as Container
    if finca == null:
        push_error("No se encontró la pestaña Finca para montar la pantalla principal.")
        return

    for legacy_name in ["BuildingList", "BuildingPanel"]:
        var legacy_control := finca.get_node_or_null(legacy_name) as Control
        if legacy_control != null:
            legacy_control.visible = false
            legacy_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var screen := finca.get_node_or_null("FincaScreen") as Control
    if screen == null:
        screen = FINCA_SCREEN.instantiate() as Control
        if screen == null:
            push_error("No se pudo instanciar FincaScreen.")
            return
        screen.name = "FincaScreen"
        screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
        finca.add_child(screen)

    _disable_embedded_finca_shell(screen)
    finca.set_meta("primary_finca_screen", true)

func _attach_arena_screen(tabs: TabContainer) -> void:
    var arena := tabs.get_node_or_null("Arena") as VBoxContainer
    if arena == null:
        push_error("No se encontró la pestaña Arena para montar ArenaScreen.")
        return

    for child in arena.get_children():
        if child.name == "ArenaScreen":
            continue
        if child is Control:
            var legacy_control := child as Control
            legacy_control.visible = false
            legacy_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var scene := get_tree().current_scene
    if scene != null:
        var legacy_result_handler := Callable(scene, "_on_combat_finished")
        if CombatManager.combat_finished.is_connected(legacy_result_handler):
            CombatManager.combat_finished.disconnect(legacy_result_handler)
        var legacy_failure_handler := Callable(scene, "_on_action_failed")
        if CombatManager.combat_failed.is_connected(legacy_failure_handler):
            CombatManager.combat_failed.disconnect(legacy_failure_handler)

    var screen := arena.get_node_or_null("ArenaScreen") as Control
    if screen == null:
        screen = ARENA_SCREEN.instantiate() as Control
        if screen == null:
            push_error("No se pudo instanciar ArenaScreen.")
            return
        screen.name = "ArenaScreen"
        screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
        arena.add_child(screen)
        arena.move_child(screen, 0)
    arena.set_meta("primary_arena_screen", true)

func _disable_embedded_finca_shell(screen: Control) -> void:
    for path in ["TopHUD", "MainNavigation", "BottomStatusBar"]:
        var control := screen.get_node_or_null(path) as Control
        if control != null:
            control.visible = false
            control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var callback := Callable(screen, "_on_visibility_changed")
    if screen.visibility_changed.is_connected(callback):
        screen.visibility_changed.disconnect(callback)

func _attach_unified_hud(root: Control) -> void:
    var shell := root.get_node_or_null("UnifiedHudShell") as Control
    if shell == null:
        shell = UNIFIED_HUD.instantiate() as Control
        if shell == null:
            push_error("No se pudo instanciar el HUD unificado.")
            return
        shell.name = "UnifiedHudShell"
        root.add_child(shell)
    root.move_child(shell, root.get_child_count() - 1)

func _enforce_unified_layout() -> void:
    if main_root == null or main_tabs == null:
        return
    main_tabs.tabs_visible = false

    for path in ["Margin/VBox/Title", "Margin/VBox/Resources", "Margin/VBox/TopButtons"]:
        var legacy_control := main_root.get_node_or_null(path) as Control
        if legacy_control != null:
            legacy_control.visible = false
            legacy_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var margin := main_root.get_node_or_null("Margin") as MarginContainer
    if margin != null:
        margin.offset_left = 12.0
        margin.offset_top = 112.0
        margin.offset_right = -12.0
        margin.offset_bottom = -80.0

    var finca_screen := main_tabs.get_node_or_null("Finca/FincaScreen") as Control
    if finca_screen != null:
        _disable_embedded_finca_shell(finca_screen)

func _on_tab_changed(_tab_index: int) -> void:
    call_deferred("_enforce_unified_layout")

func _select_finca_as_primary_view(tabs: TabContainer) -> void:
    await get_tree().process_frame
    var finca := tabs.get_node_or_null("Finca") as Control
    if finca == null:
        return
    var finca_index := tabs.get_tab_idx_from_control(finca)
    if finca_index >= 0:
        tabs.current_tab = finca_index
    _enforce_unified_layout()

func _go_to_finca() -> void:
    FincaHubController.show_finca()
