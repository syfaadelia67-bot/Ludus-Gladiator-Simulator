extends Node

const UNIFIED_HUD = preload("res://scenes/UnifiedHudShell.tscn")
const MAX_ATTACH_ATTEMPTS := 30

var main_root: Control
var main_tabs: TabContainer

func _ready() -> void:
    _attach_when_ready()

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
        _disconnect_legacy_combat_handlers(root)
        _attach_unified_hud(root)
        _enforce_primary_hud_layout()
        if not FincaHubController.prepare_scene():
            continue
        call_deferred("_open_finca_as_primary_view")
        return
    push_error("No se pudo preparar el HUD principal y su ScreenHost.")

func _disconnect_legacy_combat_handlers(root: Control) -> void:
    var legacy_result_handler := Callable(root, "_on_combat_finished")
    if CombatManager.combat_finished.is_connected(legacy_result_handler):
        CombatManager.combat_finished.disconnect(legacy_result_handler)
    var legacy_failure_handler := Callable(root, "_on_action_failed")
    if CombatManager.combat_failed.is_connected(legacy_failure_handler):
        CombatManager.combat_failed.disconnect(legacy_failure_handler)

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

func _enforce_primary_hud_layout() -> void:
    if main_root == null or main_tabs == null:
        return
    main_tabs.tabs_visible = false
    main_tabs.visible = false
    main_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE

    for path in ["Margin/VBox/Title", "Margin/VBox/Resources", "Margin/VBox/TopButtons"]:
        var legacy_control := main_root.get_node_or_null(path) as Control
        if legacy_control != null:
            legacy_control.visible = false
            legacy_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var margin := main_root.get_node_or_null("Margin") as MarginContainer
    if margin != null:
        margin.offset_left = 12.0
        margin.offset_top = 66.0
        margin.offset_right = -96.0
        margin.offset_bottom = -80.0

func _open_finca_as_primary_view() -> void:
    await get_tree().process_frame
    FincaHubController.show_finca()
    _enforce_primary_hud_layout()
