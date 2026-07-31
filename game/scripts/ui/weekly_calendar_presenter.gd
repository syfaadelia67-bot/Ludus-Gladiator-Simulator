extends Node

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
    calendar.custom_minimum_size = Vector2(0, 245)
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

    lines.append("[b]PRÓXIMOS COMBATES[/b]")
    for offset in range(4):
        var week := GameState.get_week() + offset
        var details: Dictionary = CombatManager.get_event_details_for_week(week)
        var current_marker := "→ " if offset == 0 else ""
        lines.append("%sSemana %d — %s" % [current_marker, week, details.get("name", "Evento semanal")])
    calendar.text = "\n".join(lines)
