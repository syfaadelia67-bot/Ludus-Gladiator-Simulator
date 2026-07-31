extends Node

func _ready() -> void:
    call_deferred("_attach")
    GameState.week_advanced.connect(func(_week: int): call_deferred("_refresh"))

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
    var calendar := RichTextLabel.new()
    calendar.name = "WeeklyCalendar"
    calendar.bbcode_enabled = true
    calendar.fit_content = true
    calendar.custom_minimum_size = Vector2(0, 130)
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
    var lines: Array[String] = ["[b]CALENDARIO SEMANAL[/b]"]
    for offset in range(4):
        var week := GameState.get_week() + offset
        var details: Dictionary = CombatManager.get_event_details_for_week(week)
        lines.append("Semana %d — %s" % [week, details.get("name", "Evento semanal")])
    calendar.text = "\n".join(lines)
