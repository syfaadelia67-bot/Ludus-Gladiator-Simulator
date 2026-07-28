extends Node

const PANEL_SCENE = preload("res://scenes/RelationshipsPanel.tscn")

func _ready() -> void:
    call_deferred("_attach_panel")

func _attach_panel() -> void:
    var tree := get_tree()
    if tree == null:
        return
    var root := tree.current_scene
    if root == null:
        return
    var tabs := root.find_child("MainTabs", true, false)
    if tabs == null or not tabs is TabContainer:
        return
    if tabs.has_node("Relaciones"):
        return
    var panel = PANEL_SCENE.instantiate()
    panel.name = "Relaciones"
    tabs.add_child(panel)
