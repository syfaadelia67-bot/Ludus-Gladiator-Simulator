extends Node

const MAX_BIND_ATTEMPTS := 30

var advance_button: Button
var activity_log: RichTextLabel

func _ready() -> void:
    GameState.week_advanced.connect(_on_week_advanced)
    call_deferred("_bind")

func _bind() -> void:
    for _attempt in range(MAX_BIND_ATTEMPTS):
        await get_tree().process_frame
        var root := get_tree().current_scene
        if root == null:
            continue
        advance_button = root.get_node_or_null("Margin/VBox/TopButtons/AdvanceDay") as Button
        activity_log = root.get_node_or_null("Margin/VBox/Tabs/Personal/Log") as RichTextLabel
        if advance_button != null:
            advance_button.text = "Cerrar semana"
            advance_button.tooltip_text = "Procesa siete días internos, aplica gastos y abre la siguiente semana de campaña."
            return

func _on_week_advanced(week: int) -> void:
    call_deferred("_normalize_week_log", week)

func _normalize_week_log(week: int) -> void:
    if activity_log == null:
        return
    activity_log.text = activity_log.text.replace("[b]Día %d[/b]" % week, "[b]Semana %d[/b]" % week)
    var fight: Dictionary = CombatManager.get_current_event_details()
    activity_log.append_text("\n[color=gold]Combate programado: %s.[/color]" % str(fight.get("name", "Arena semanal")))
