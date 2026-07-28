extends Node

const EVENTS_PANEL = preload("res://scenes/EventsPanel.tscn")

func _ready() -> void:
    call_deferred("_install_panel")

func _install_panel() -> void:
    var tabs := get_tree().root.get_node_or_null("Main/Margin/VBox/Tabs") as TabContainer
    if tabs == null:
        await get_tree().process_frame
        tabs = get_tree().root.get_node_or_null("Main/Margin/VBox/Tabs") as TabContainer
    if tabs == null or tabs.has_node("Eventos"):
        return
    var panel := EVENTS_PANEL.instantiate()
    tabs.add_child(panel)
