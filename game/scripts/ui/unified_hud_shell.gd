extends Control

const PRIMARY_SYSTEMS := {
    "finca":"Finca",
    "personal":"Personal",
    "mercado":"Mercado",
    "forja":"Forja",
    "relaciones":"Relaciones",
    "arena":"Arena",
    "campana":"Campaña"
}

const MORE_SYSTEMS := [
    {"id":"eventos", "label":"Eventos"},
    {"id":"rivales", "label":"Rivales"},
    {"id":"economia", "label":"Economía"},
    {"id":"torneos", "label":"Torneos"},
    {"id":"progresion", "label":"Progresión"},
    {"id":"equipamiento", "label":"Equipamiento"},
    {"id":"personalidad", "label":"Personalidad"},
    {"id":"transferencias", "label":"Transferencias"},
    {"id":"historial", "label":"Historial"}
]

@onready var resource_summary: Label = $TopHUD/Margin/Row/Resources
@onready var week_summary: Label = $TopHUD/Margin/Row/Week
@onready var advance_week_button: Button = $TopHUD/Margin/Row/AdvanceWeek
@onready var section_label: Label = $MainNavigation/Margin/Row/Section
@onready var more_button: MenuButton = $MainNavigation/Margin/Row/More
@onready var injuries_alert: Label = $BottomStatusBar/Margin/Row/Injuries
@onready var food_alert: Label = $BottomStatusBar/Margin/Row/Food
@onready var workers_alert: Label = $BottomStatusBar/Margin/Row/Workers
@onready var event_alert: Label = $BottomStatusBar/Margin/Row/Event
@onready var combat_alert: Label = $BottomStatusBar/Margin/Row/Combat

var primary_buttons: Dictionary = {}
var more_ids: Array[String] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    primary_buttons = {
        "finca":$MainNavigation/Margin/Row/Finca,
        "personal":$MainNavigation/Margin/Row/Personal,
        "mercado":$MainNavigation/Margin/Row/Mercado,
        "forja":$MainNavigation/Margin/Row/Forja,
        "relaciones":$MainNavigation/Margin/Row/Relaciones,
        "arena":$MainNavigation/Margin/Row/Arena,
        "campana":$MainNavigation/Margin/Row/Campana
    }
    for system_id in primary_buttons.keys():
        var button := primary_buttons[system_id] as Button
        if button != null:
            button.pressed.connect(_open_system.bind(str(system_id)))

    advance_week_button.pressed.connect(_advance_week)
    _build_more_menu()

    GameState.resources_changed.connect(_refresh_all)
    GameState.week_advanced.connect(func(_week: int): _refresh_all())
    RosterManager.roster_changed.connect(_refresh_all)
    EventManager.events_changed.connect(_refresh_alerts)
    CombatManager.combat_finished.connect(func(_result: Dictionary): _refresh_alerts())
    FincaHubController.system_opened.connect(_on_system_opened)
    FincaHubController.hub_opened.connect(func(): _refresh_navigation("finca"))

    call_deferred("_refresh_all")

func _build_more_menu() -> void:
    var popup := more_button.get_popup()
    popup.clear()
    more_ids.clear()
    for entry: Dictionary in MORE_SYSTEMS:
        var system_id := str(entry.get("id", ""))
        var label := str(entry.get("label", system_id.capitalize()))
        if system_id.is_empty():
            continue
        var item_id := more_ids.size()
        more_ids.append(system_id)
        popup.add_item(label, item_id)
    if not popup.id_pressed.is_connected(_on_more_pressed):
        popup.id_pressed.connect(_on_more_pressed)

func _on_more_pressed(item_id: int) -> void:
    if item_id < 0 or item_id >= more_ids.size():
        return
    _open_system(more_ids[item_id])

func _open_system(system_id: String) -> void:
    FincaHubController.open_system(system_id)

func _advance_week() -> void:
    GameState.advance_week()

func _on_system_opened(system_id: String) -> void:
    _refresh_navigation(system_id)
    _refresh_all()

func _refresh_all() -> void:
    if not is_inside_tree():
        return
    _refresh_top_hud()
    _refresh_alerts()
    _refresh_navigation(FincaHubController.get_current_system_id())

func _refresh_top_hud() -> void:
    var people := RosterManager.get_people()
    var morale_total := 0
    for person in people:
        morale_total += int(person.morale)
    var average_morale := int(round(float(morale_total) / float(maxi(1, people.size()))))
    resource_summary.text = "DENARIOS %d   ·   COMIDA %d   ·   MINERAL %d   ·   REPUTACIÓN %d   ·   MORAL %d%%" % [
        GameState.denarii,
        GameState.food,
        GameState.ore,
        GameState.reputation,
        average_morale
    ]
    week_summary.text = "SEMANA %d" % GameState.get_week()
    advance_week_button.disabled = CampaignManager.campaign_over

func _refresh_navigation(system_id: String) -> void:
    var normalized := system_id.strip_edges().to_lower()
    if normalized.is_empty():
        normalized = "finca"
    for primary_id in primary_buttons.keys():
        var button := primary_buttons[primary_id] as Button
        if button != null:
            button.disabled = str(primary_id) == normalized

    var display_name := str(PRIMARY_SYSTEMS.get(normalized, ""))
    if display_name.is_empty():
        for entry: Dictionary in MORE_SYSTEMS:
            if str(entry.get("id", "")) == normalized:
                display_name = str(entry.get("label", normalized.capitalize()))
                break
    if display_name.is_empty():
        display_name = normalized.capitalize()
    section_label.text = "SECCIÓN · %s" % display_name.to_upper()
    more_button.text = "MÁS · %s" % display_name.to_upper() if not PRIMARY_SYSTEMS.has(normalized) else "MÁS"

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
