extends VBoxContainer

const BUILDING_LAYOUT := [
    {"id":"dominus_house", "x":0.37, "y":0.14, "w":0.22, "h":0.13},
    {"id":"barracks", "x":0.04, "y":0.23, "w":0.22, "h":0.13},
    {"id":"training_yard", "x":0.28, "y":0.45, "w":0.25, "h":0.13},
    {"id":"forge", "x":0.73, "y":0.25, "w":0.20, "h":0.13},
    {"id":"infirmary", "x":0.04, "y":0.53, "w":0.20, "h":0.12},
    {"id":"kitchen", "x":0.72, "y":0.54, "w":0.21, "h":0.12},
    {"id":"warehouse", "x":0.80, "y":0.09, "w":0.16, "h":0.11},
    {"id":"worker_quarters", "x":0.04, "y":0.75, "w":0.22, "h":0.11},
    {"id":"wall_and_gate", "x":0.39, "y":0.85, "w":0.22, "h":0.10},
    {"id":"beast_area", "x":0.76, "y":0.76, "w":0.20, "h":0.11},
    {"id":"sanctuary", "x":0.61, "y":0.09, "w":0.16, "h":0.11},
    {"id":"private_arena", "x":0.50, "y":0.63, "w":0.22, "h":0.12},
    {"id":"stable", "x":0.30, "y":0.75, "w":0.17, "h":0.11}
]

const BUILDING_SYSTEMS := {
    "dominus_house":"campana",
    "barracks":"barracks",
    "training_yard":"personal",
    "forge":"forja",
    "infirmary":"personal"
}

const HOTSPOT_NAMES := {
    "dominus_house":"Casa del Dominus",
    "barracks":"Barracones",
    "training_yard":"Patio de entrenamiento",
    "forge":"Forja",
    "infirmary":"Enfermería",
    "kitchen":"Cocina y comedor",
    "warehouse":"Almacén",
    "worker_quarters":"Trabajadores",
    "wall_and_gate":"Muralla y puerta",
    "beast_area":"Bestias",
    "sanctuary":"Santuario",
    "private_arena":"Arena privada",
    "stable":"Establo"
}

@onready var resource_summary: Label = $TopHUD/Margin/Row/Resources
@onready var week_summary: Label = $TopHUD/Margin/Row/Week
@onready var advance_week_button: Button = $TopHUD/Margin/Row/AdvanceWeek
@onready var world_area: Control = $Center/WorldPanel/WorldMargin/WorldArea
@onready var details_scroll: ScrollContainer = $Center/BuildingDetailsPanel/Margin/Scroll
@onready var building_title: Label = $Center/BuildingDetailsPanel/Margin/Scroll/Details/Title
@onready var building_status: Label = $Center/BuildingDetailsPanel/Margin/Scroll/Details/Status
@onready var building_description: RichTextLabel = $Center/BuildingDetailsPanel/Margin/Scroll/Details/Description
@onready var building_effect: Label = $Center/BuildingDetailsPanel/Margin/Scroll/Details/Effect
@onready var building_next_upgrade: Label = $Center/BuildingDetailsPanel/Margin/Scroll/Details/NextUpgrade
@onready var building_cost: Label = $Center/BuildingDetailsPanel/Margin/Scroll/Details/Cost
@onready var feedback: Label = $Center/BuildingDetailsPanel/Margin/Scroll/Details/Feedback
@onready var enter_button: Button = $Center/BuildingDetailsPanel/Margin/Scroll/Details/Enter
@onready var upgrade_button: Button = $Center/BuildingDetailsPanel/Margin/Scroll/Details/Upgrade
@onready var injuries_alert: Label = $BottomStatusBar/Margin/Row/Injuries
@onready var food_alert: Label = $BottomStatusBar/Margin/Row/Food
@onready var workers_alert: Label = $BottomStatusBar/Margin/Row/Workers
@onready var event_alert: Label = $BottomStatusBar/Margin/Row/Event
@onready var combat_alert: Label = $BottomStatusBar/Margin/Row/Combat

var selected_building_id := "dominus_house"
var hotspot_buttons: Dictionary = {}

func _ready() -> void:
    advance_week_button.pressed.connect(_advance_week)
    enter_button.pressed.connect(_open_selected_building)
    upgrade_button.pressed.connect(_upgrade_selected_building)
    $MainNavigation/Margin/Row/Personal.pressed.connect(_open_system.bind("barracks"))
    $MainNavigation/Margin/Row/Mercado.pressed.connect(_open_system.bind("mercado"))
    $MainNavigation/Margin/Row/Forja.pressed.connect(_open_system.bind("forja"))
    $MainNavigation/Margin/Row/Relaciones.pressed.connect(_open_system.bind("relaciones"))
    $MainNavigation/Margin/Row/Arena.pressed.connect(_open_system.bind("arena"))
    $MainNavigation/Margin/Row/Campana.pressed.connect(_open_system.bind("campana"))

    EstateManager.estate_changed.connect(_refresh_all)
    EstateManager.upgrade_completed.connect(_on_upgrade_completed)
    EstateManager.upgrade_failed.connect(_on_upgrade_failed)
    GameState.resources_changed.connect(_refresh_all)
    GameState.week_advanced.connect(func(_week: int): _refresh_all())
    RosterManager.roster_changed.connect(_refresh_all)
    EventManager.events_changed.connect(_refresh_alerts)
    CombatManager.combat_finished.connect(func(_result: Dictionary): _refresh_alerts())
    world_area.resized.connect(_layout_hotspots)

    _build_hotspots()
    _refresh_all()
    _select_building(selected_building_id)
    call_deferred("_layout_hotspots")

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()

func _build_hotspots() -> void:
    for entry: Dictionary in BUILDING_LAYOUT:
        var building_id := str(entry.get("id", ""))
        if building_id.is_empty():
            continue
        var button := Button.new()
        button.name = "Hotspot_%s" % building_id
        button.focus_mode = Control.FOCUS_ALL
        button.clip_text = true
        button.add_theme_font_size_override("font_size", 14)
        button.pressed.connect(_select_building.bind(building_id))
        world_area.add_child(button)
        hotspot_buttons[building_id] = button

func _layout_hotspots() -> void:
    if world_area == null or not is_instance_valid(world_area):
        return
    var area_size := world_area.size
    if area_size.x <= 0.0 or area_size.y <= 0.0:
        return
    for entry: Dictionary in BUILDING_LAYOUT:
        var building_id := str(entry.get("id", ""))
        var button := hotspot_buttons.get(building_id) as Button
        if button == null:
            continue
        var button_size := Vector2(
            clampf(area_size.x * float(entry.get("w", 0.15)), 96.0, 190.0),
            clampf(area_size.y * float(entry.get("h", 0.11)), 40.0, 62.0)
        )
        var desired_position := Vector2(
            area_size.x * float(entry.get("x", 0.0)),
            area_size.y * float(entry.get("y", 0.0))
        )
        desired_position.x = clampf(desired_position.x, 4.0, maxf(4.0, area_size.x - button_size.x - 4.0))
        desired_position.y = clampf(desired_position.y, 72.0, maxf(72.0, area_size.y - button_size.y - 4.0))
        button.position = desired_position
        button.size = button_size

func _refresh_all() -> void:
    _refresh_top_hud()
    _refresh_hotspots()
    _refresh_selected_building()
    _refresh_alerts()

func _refresh_top_hud() -> void:
    var people := RosterManager.get_people()
    var morale_total := 0
    for person in people:
        morale_total += int(person.morale)
    var average_morale := int(round(float(morale_total) / float(maxi(1, people.size()))))
    resource_summary.text = "Denarios %d  ·  Comida %d  ·  Mineral %d  ·  Reputación %d  ·  Moral %d%%" % [
        GameState.denarii,
        GameState.food,
        GameState.ore,
        GameState.reputation,
        average_morale
    ]
    week_summary.text = "SEMANA %d" % GameState.get_week()
    advance_week_button.disabled = CampaignManager.campaign_over

func _refresh_hotspots() -> void:
    for building_id in hotspot_buttons.keys():
        var button := hotspot_buttons[building_id] as Button
        if button == null:
            continue
        var data := EstateManager.get_building_data(str(building_id))
        if data.is_empty():
            button.visible = false
            continue
        var locked := bool(data.get("locked", false))
        var level := int(data.get("level", 0))
        var display_name := str(HOTSPOT_NAMES.get(building_id, data.get("name", building_id)))
        button.text = "%s\n%s" % [display_name, "EN CONSTRUCCIÓN" if locked else "Nivel %d" % level]
        button.tooltip_text = "%s\n%s" % [str(data.get("name", building_id)), str(data.get("description", ""))]
        button.self_modulate = Color(0.55, 0.55, 0.55, 0.88) if locked else Color.WHITE

func _select_building(building_id: String) -> void:
    selected_building_id = EstateManager.canonicalize_building_id(building_id)
    feedback.text = ""
    _refresh_selected_building()
    call_deferred("_scroll_details_to_top")

func _scroll_details_to_top() -> void:
    if details_scroll != null and is_instance_valid(details_scroll):
        details_scroll.scroll_vertical = 0

func _refresh_selected_building() -> void:
    var data := EstateManager.get_building_data(selected_building_id)
    if data.is_empty():
        building_title.text = "INSTALACIÓN"
        building_status.text = "No disponible"
        building_description.text = "Seleccioná un edificio del mapa."
        enter_button.disabled = true
        upgrade_button.disabled = true
        return

    var locked := bool(data.get("locked", false))
    var level := int(data.get("level", 0))
    var max_level := int(data.get("effective_max_level", 0))
    building_title.text = str(data.get("name", selected_building_id)).to_upper()
    building_status.text = "BLOQUEADA · CONTENIDO POSTERIOR" if locked else "OPERATIVA · NIVEL %d" % level
    building_description.text = "[b]Descripción[/b]\n%s" % str(data.get("description", "Sin descripción."))
    building_effect.text = "Efecto actual: %s" % _building_effect_text(data)

    if locked:
        building_next_upgrade.text = "Próxima mejora: disponible después de la demo."
        building_cost.text = "Costo: —"
        enter_button.text = "No disponible en la demo"
        enter_button.disabled = true
        upgrade_button.disabled = true
        return

    if level >= max_level:
        building_next_upgrade.text = "Próxima mejora: nivel máximo disponible en la demo."
        building_cost.text = "Costo: —"
    else:
        building_next_upgrade.text = "Próxima mejora: nivel %d" % (level + 1)
        building_cost.text = "Costo: %d denarios" % int(data.get("upgrade_cost", 0))

    if selected_building_id == "kitchen":
        enter_button.text = "Gestionar provisiones"
        enter_button.disabled = false
    else:
        var system_id := str(BUILDING_SYSTEMS.get(selected_building_id, ""))
        enter_button.text = _entry_button_text(selected_building_id)
        enter_button.disabled = system_id.is_empty()
    upgrade_button.disabled = not EstateManager.can_upgrade(selected_building_id)

func _building_effect_text(data: Dictionary) -> String:
    if bool(data.get("locked", false)):
        return "Sin efecto mientras la instalación permanezca bloqueada."
    var level := int(data.get("level", 0))
    match str(data.get("effect_type", "")):
        "administration":
            return "Administración del ludus y acceso a decisiones de campaña."
        "capacity":
            return "Capacidad de personal %s." % RosterManager.get_capacity_summary()
        "training_multiplier":
            return "Velocidad de entrenamiento x%.2f." % EstateManager.get_training_multiplier()
        "forge_level":
            return "Forja operativa en nivel %d." % EstateManager.get_forge_level()
        "recovery_bonus":
            return "+%d de recuperación semanal." % EstateManager.get_recovery_bonus()
        "food_efficiency":
            return "+%d%% de eficiencia alimentaria proyectada." % (level * 10)
        _:
            return "Efecto reservado para una actualización posterior."

func _entry_button_text(building_id: String) -> String:
    match building_id:
        "dominus_house":
            return "Entrar a administración"
        "barracks":
            return "Entrar a barracones"
        "training_yard":
            return "Organizar entrenamiento"
        "forge":
            return "Entrar a la forja"
        "infirmary":
            return "Revisar heridos"
        _:
            return "Entrar"

func _open_selected_building() -> void:
    if EstateManager.is_locked(selected_building_id):
        feedback.text = "Esta instalación se encuentra bloqueada en la demo."
        return
    if selected_building_id == "kitchen":
        var weekly_need := maxi(1, RosterManager.get_people().size() * GameState.DAYS_PER_WEEK)
        feedback.text = "Provisiones actuales: %d. Consumo semanal estimado: %d. La gestión detallada de cocina se incorporará en su pantalla propia." % [GameState.food, weekly_need]
        return
    var system_id := str(BUILDING_SYSTEMS.get(selected_building_id, ""))
    if system_id.is_empty() or not FincaHubController.open_system(system_id):
        feedback.text = "El sistema de esta instalación todavía no está disponible."

func _upgrade_selected_building() -> void:
    feedback.text = ""
    EstateManager.upgrade(selected_building_id)

func _on_upgrade_completed(building_id: String, new_level: int) -> void:
    if EstateManager.canonicalize_building_id(building_id) == selected_building_id:
        feedback.text = "Instalación mejorada al nivel %d." % new_level
    _refresh_all()

func _on_upgrade_failed(reason: String) -> void:
    feedback.text = reason
    _refresh_selected_building()

func _advance_week() -> void:
    GameState.advance_week()

func _open_system(system_id: String) -> void:
    FincaHubController.open_system(system_id)

func _refresh_alerts() -> void:
    var injured := 0
    var idle_workers := 0
    for person in RosterManager.get_people():
        if int(person.injury_days) > 0:
            injured += 1
        if str(person.job) == "idle":
            idle_workers += 1

    injuries_alert.text = "LESIONES\n%d persona(s) heridas" % injured
    var weekly_need := maxi(1, RosterManager.get_people().size() * GameState.DAYS_PER_WEEK)
    food_alert.text = "COMIDA\n%d disponibles · %s" % [GameState.food, "RIESGO" if GameState.food < weekly_need else "Suficiente"]
    workers_alert.text = "PERSONAL\n%d sin asignación · %s" % [idle_workers, RosterManager.get_capacity_summary()]

    var pending: Dictionary = EventManager.get_pending_event()
    event_alert.text = "EVENTO\n%s" % (str(pending.get("title", pending.get("name", "Decisión pendiente"))) if not pending.is_empty() else "Sin decisión pendiente")

    var event_details: Dictionary = CombatManager.get_current_event_details()
    var combat_done := CombatManager.last_combat_day == GameState.day
    combat_alert.text = "ARENA\n%s · %s" % [
        str(event_details.get("name", "Combate semanal")),
        "Completado" if combat_done else "Pendiente"
    ]
