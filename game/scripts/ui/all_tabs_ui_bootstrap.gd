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
    {"name":"Transferencias", "scene":preload("res://scenes/TransfersPanel.tscn")}
]

const MAX_ATTACH_ATTEMPTS := 30

func _ready() -> void:
    _attach_when_ready()

func _attach_when_ready() -> void:
    for _attempt in range(MAX_ATTACH_ATTEMPTS):
        await get_tree().process_frame
        var root := get_tree().current_scene
        if root == null or not root.is_inside_tree():
            continue
        var tabs := root.find_child("Tabs", true, false)
        if tabs is TabContainer:
            _attach_panels(tabs)
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
