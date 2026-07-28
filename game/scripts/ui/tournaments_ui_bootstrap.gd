extends Node

const TOURNAMENTS_PANEL = preload("res://scenes/TournamentsPanel.tscn")

func _ready() -> void:
    call_deferred("_install_panel")

func _install_panel() -> void:
    var tabs := get_tree().root.get_node_or_null("Main/Margin/VBox/Tabs") as TabContainer
    if tabs == null:
        await get_tree().process_frame
        tabs = get_tree().root.get_node_or_null("Main/Margin/VBox/Tabs") as TabContainer
    if tabs == null or tabs.has_node("Torneos"):
        return
    tabs.add_child(TOURNAMENTS_PANEL.instantiate())
