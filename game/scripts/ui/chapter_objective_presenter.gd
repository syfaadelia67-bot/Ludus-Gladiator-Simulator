extends Node

func _ready() -> void:
    ChapterObjectiveController.chapter_objectives_changed.connect(func(): call_deferred("_refresh"))
    call_deferred("_attach")

func _attach() -> void:
    for _attempt in range(90):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null:
            continue
        var panel := scene.find_child("Campaña", true, false)
        if panel == null:
            continue
        var objectives := panel.get_node_or_null("Objectives") as RichTextLabel
        if objectives == null:
            continue
        objectives.name = "LegacyObjectives"
        objectives.visible = false
        if panel.get_node_or_null("ChapterObjectiveScroll") == null:
            var scroll := ScrollContainer.new()
            scroll.name = "ChapterObjectiveScroll"
            scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
            panel.add_child(scroll)
            var text := RichTextLabel.new()
            text.name = "ChapterObjectiveDetails"
            text.bbcode_enabled = true
            text.fit_content = true
            text.custom_minimum_size = Vector2(0, 360)
            scroll.add_child(text)
        _refresh()
        return

func _refresh() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var text := scene.find_child("ChapterObjectiveDetails", true, false) as RichTextLabel
    if text == null:
        return
    var overview := ChapterObjectiveController.get_current_overview()
    var chapter: Dictionary = overview.get("chapter", {})
    var lines: Array[String] = []
    lines.append("[font_size=22][b]CAPÍTULO %d · %s[/b][/font_size]" % [int(chapter.get("number", 1)), str(chapter.get("name", "Campaña"))])
    lines.append(str(chapter.get("description", "")))
    lines.append("[b]Plazo:[/b] semana %d · quedan %d semana(s)" % [int(overview.get("deadline_week", 0)), int(overview.get("weeks_remaining", 0))])
    lines.append("")
    for objective in overview.get("objectives", []):
        var status := str(objective.get("status", "en_progreso"))
        var icon := "✓" if status == "completado" else ("✕" if status == "fallido" else ("!" if status == "en_riesgo" else "•"))
        var role := "OBJETIVO PRINCIPAL" if bool(objective.get("primary", false)) else "Objetivo secundario"
        lines.append("[b]%s %s · %s[/b]" % [icon, role, str(objective.get("title", "Objetivo"))])
        lines.append(str(objective.get("description", "")))
        lines.append("Progreso: %d/%d · recompensa: %d denarios y %d reputación" % [int(objective.get("progress", 0)), int(objective.get("target", 1)), int(objective.get("reward_denarii", 0)), int(objective.get("reward_reputation", 0))])
        lines.append("")
    lines.append("[b]HITOS DEL CALENDARIO[/b]")
    for milestone in overview.get("milestones", []):
        if int(milestone.get("week", 0)) >= GameState.get_week():
            lines.append("Semana %d · %s" % [int(milestone.get("week", 0)), str(milestone.get("label", "Hito"))])
    text.text = "\n".join(lines)
