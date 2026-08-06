extends Node

const UNIFIED_HUD = preload("res://scenes/UnifiedHudShell.tscn")
const MAX_ATTACH_ATTEMPTS := 30
const MAIN_SCENE_NAME := "Main"

var main_root: Control

func _ready() -> void:
    _attach_when_ready()

func _attach_when_ready() -> void:
    for _attempt in range(MAX_ATTACH_ATTEMPTS):
        await get_tree().process_frame
        var root := get_tree().current_scene as Control
        if root == null or not root.is_inside_tree():
            continue
        if root.name != MAIN_SCENE_NAME:
            return
        main_root = root
        _attach_unified_hud(root)
        _enforce_primary_hud_layout()
        if not FincaHubController.prepare_scene():
            continue
        call_deferred("_open_finca_as_primary_view")
        return
    push_error("No se pudo preparar el HUD principal y su ScreenHost.")

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
    if main_root == null:
        return

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
