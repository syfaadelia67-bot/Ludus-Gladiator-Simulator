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

const ARENA_CONTROLLER = preload("res://scripts/ui/arena_experience_controller.gd")
const MAX_ATTACH_ATTEMPTS := 30

func _ready() -> void:
    _attach_when_ready()

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and FincaHubController.get_current_system_id() == "arena":
        _go_to_finca()
        get_viewport().set_input_as_handled()

func _attach_when_ready() -> void:
    for _attempt in range(MAX_ATTACH_ATTEMPTS):
        await get_tree().process_frame
        var root := get_tree().current_scene
        if root == null or not root.is_inside_tree():
            continue
        var tabs := root.find_child("Tabs", true, false)
        if tabs is TabContainer:
            _attach_panels(tabs)
            _attach_arena_controller(tabs)
            call_deferred("_repair_arena_navigation", tabs)
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

func _attach_arena_controller(tabs: TabContainer) -> void:
    var arena := tabs.get_node_or_null("Arena") as VBoxContainer
    if arena == null:
        push_error("No se encontró la pestaña Arena para activar el combate mejorado.")
        return
    if arena.has_meta("enhanced_combat_ui"):
        return
    var controller := Node.new()
    controller.name = "ArenaExperienceController"
    controller.set_script(ARENA_CONTROLLER)
    arena.add_child(controller)
    controller.call_deferred("setup", arena)

func _repair_arena_navigation(tabs: TabContainer) -> void:
    await get_tree().process_frame
    var arena := tabs.get_node_or_null("Arena") as VBoxContainer
    if arena == null:
        return
    var navigation := arena.get_node_or_null("ArenaNavigation") as HBoxContainer
    if navigation == null:
        navigation = HBoxContainer.new()
        navigation.name = "ArenaNavigation"
        arena.add_child(navigation)
        arena.move_child(navigation, 0)

    var finca_button := navigation.get_node_or_null("BackToFinca") as Button
    if finca_button == null:
        finca_button = Button.new()
        finca_button.name = "BackToFinca"
        navigation.add_child(finca_button)
        navigation.move_child(finca_button, 0)
    finca_button.text = "← Volver a la finca"
    finca_button.tooltip_text = "Salir de la Arena y regresar al centro del ludus. También podés usar Esc."
    if not finca_button.pressed.is_connected(_go_to_finca):
        finca_button.pressed.connect(_go_to_finca)

    var personal_button := navigation.get_node_or_null("BackToPersonal") as Button
    if personal_button == null:
        for control in navigation.get_children():
            if control is Button and control != finca_button and str(control.text).contains("Volver"):
                personal_button = control
                personal_button.name = "BackToPersonal"
                break
    if personal_button == null:
        personal_button = Button.new()
        personal_button.name = "BackToPersonal"
        navigation.add_child(personal_button)
    personal_button.text = "Volver a Personal"
    personal_button.tooltip_text = "Salir de la Arena y revisar el gladiador seleccionado."
    if not personal_button.pressed.is_connected(_go_to_personal):
        personal_button.pressed.connect(_go_to_personal)

func _go_to_finca() -> void:
    FincaHubController.show_finca()

func _go_to_personal() -> void:
    FincaHubController.open_system("personal")
