extends Node

const DEMO_FINAL_WEEK := 16
const REQUIRED_FINALE_WINS := 6

func _ready() -> void:
    call_deferred("_attach")
    GameState.week_advanced.connect(func(_week: int): call_deferred("_refresh"))
    CampaignManager.campaign_changed.connect(func(): call_deferred("_refresh"))

func _attach() -> void:
    var root := get_tree().current_scene
    if root == null:
        return
    var tabs := root.find_child("Tabs", true, false) as TabContainer
    if tabs == null:
        return
    var panel := tabs.get_node_or_null("Campaña") as VBoxContainer
    if panel == null:
        return
    var existing := panel.get_node_or_null("WeeklyCalendar") as RichTextLabel
    if existing != null:
        _refresh()
        return
    var calendar := RichTextLabel.new()
    calendar.name = "WeeklyCalendar"
    calendar.bbcode_enabled = true
    calendar.fit_content = true
    calendar.custom_minimum_size = Vector2(0, 285)
    panel.add_child(calendar)
    panel.move_child(calendar, 0)
    _refresh()

func _refresh() -> void:
    var root := get_tree().current_scene
    if root == null:
        return
    var calendar := root.find_child("WeeklyCalendar", true, false) as RichTextLabel
    if calendar == null:
        return

    var chapter: Dictionary = CampaignManager.get_current_chapter()
    var lines: Array[String] = [
        "[b]CAPÍTULO %d — %s[/b]" % [int(chapter.get("number", 1)), chapter.get("name", "Campaña")],
        str(chapter.get("description", "")),
        "[b]Objetivos del capítulo[/b]"
    ]
    for objective in CampaignManager.get_current_chapter_objectives():
        var completed := bool(objective.get("completed", false))
        var marker := "✓" if completed else "•"
        lines.append("%s %s — %d/%d" % [marker, objective.get("title", "Objetivo"), int(objective.get("progress", 0)), int(objective.get("target", 1))])

    if str(chapter.get("id", "")) == "name_of_ludus":
        _append_finale_preparation(lines)

    lines.append("[b]PRÓXIMOS COMBATES[/b]")
    var current_week := GameState.get_week()
    for offset in range(4):
        var week := current_week + offset
        if week > DEMO_FINAL_WEEK:
            break
        var details: Dictionary = CombatManager.get_event_details_for_week(week)
        var current_marker := "→ " if offset == 0 else ""
        var finale_marker := " [b]— FINAL[/b]" if bool(details.get("finale", false)) else ""
        lines.append("%sSemana %d — %s%s" % [current_marker, week, details.get("name", "Evento semanal"), finale_marker])
    if current_week > DEMO_FINAL_WEEK:
        lines.append("Campaña finalizada.")
    calendar.text = "\n".join(lines)

func _append_finale_preparation(lines: Array[String]) -> void:
    var summary: Dictionary = CampaignManager.get_summary()
    var wins := int(summary.get("wins", 0))
    var missing_wins := maxi(0, REQUIRED_FINALE_WINS - wins)
    var final_resolved := bool(summary.get("final_combat_resolved", false))

    lines.append("[b]PREPARACIÓN PARA EL COMBATE FINAL[/b]")
    lines.append("Victorias acumuladas: %d/%d" % [mini(wins, REQUIRED_FINALE_WINS), REQUIRED_FINALE_WINS])
    if final_resolved:
        lines.append("El combate final ya fue resuelto.")
    elif GameState.get_week() >= DEMO_FINAL_WEEK:
        if missing_wins == 0:
            lines.append("[color=yellow]Entrá en Arena: el destino del ludus se decide en este combate.[/color]")
        else:
            lines.append("[color=red]Advertencia: faltan %d victorias. El combate final decidirá la campaña.[/color]" % missing_wins)
    elif missing_wins == 0:
        lines.append("Requisito de victorias cumplido. Prepará al gladiador para la semana 16.")
    else:
        lines.append("Faltan %d victorias antes de la semana 16." % missing_wins)
