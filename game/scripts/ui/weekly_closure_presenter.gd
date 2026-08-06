extends Node

const BUTTON_PATH := "UnifiedHudShell/TopHUD/Margin/Row/AdvanceWeek"

var overlay: ColorRect
var content_label: RichTextLabel
var confirm_button: Button
var advance_button: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    WeeklyPlanningController.planning_changed.connect(_refresh_if_open)
    call_deferred("_attach")

func _unhandled_key_input(event: InputEvent) -> void:
    if overlay != null and overlay.visible and event.is_action_pressed("ui_cancel"):
        _close()
        get_viewport().set_input_as_handled()

func _attach() -> void:
    for _attempt in range(90):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null or scene.name != "Main":
            continue
        advance_button = scene.get_node_or_null(BUTTON_PATH) as Button
        if advance_button == null:
            continue
        for connection in advance_button.pressed.get_connections():
            var callable: Callable = connection.get("callable", Callable())
            if callable.is_valid():
                advance_button.pressed.disconnect(callable)
        advance_button.pressed.connect(open_summary)
        advance_button.text = "Revisar y cerrar semana"
        advance_button.tooltip_text = "Revisa asignaciones, riesgos y economía antes de avanzar."
        _build_overlay(scene)
        return
    push_error("No se pudo conectar el resumen previo al cierre semanal.")

func _build_overlay(scene: Node) -> void:
    overlay = ColorRect.new()
    overlay.name = "WeeklyClosureSummary"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.02, 0.018, 0.016, 0.95)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.z_index = 220
    overlay.visible = false
    scene.add_child(overlay)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 110)
    margin.add_theme_constant_override("margin_top", 55)
    margin.add_theme_constant_override("margin_right", 110)
    margin.add_theme_constant_override("margin_bottom", 55)
    overlay.add_child(margin)

    var panel := PanelContainer.new()
    margin.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)

    var header := HBoxContainer.new()
    box.add_child(header)
    var title := Label.new()
    title.text = "RESUMEN ANTES DE CERRAR LA SEMANA"
    title.add_theme_font_size_override("font_size", 24)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var close_button := Button.new()
    close_button.text = "Volver"
    close_button.pressed.connect(_close)
    header.add_child(close_button)

    content_label = RichTextLabel.new()
    content_label.bbcode_enabled = true
    content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_label.custom_minimum_size = Vector2(0, 480)
    box.add_child(content_label)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_END
    box.add_child(actions)
    var cancel := Button.new()
    cancel.text = "Seguir preparando"
    cancel.pressed.connect(_close)
    actions.add_child(cancel)
    confirm_button = Button.new()
    confirm_button.text = "Confirmar cierre de semana"
    confirm_button.pressed.connect(_confirm)
    actions.add_child(confirm_button)

func open_summary() -> void:
    if overlay == null:
        return
    _render()
    overlay.visible = true

func _render() -> void:
    var summary := WeeklyPlanningController.get_summary()
    var economy: Dictionary = summary.get("economy", {})
    var lines: Array[String] = []
    lines.append("[b]Semana %d → Semana %d[/b]" % [int(summary.get("week", 1)), int(summary.get("next_week", 2))])
    lines.append("\n[b]PERSONAL Y ASIGNACIONES[/b]")
    for item in summary.get("assignments", []):
        lines.append("• %s: %s · fatiga %d" % [item.get("name", "?"), item.get("job_name", "Sin tarea"), int(item.get("fatigue", 0))])

    lines.append("\n[b]ENTRENAMIENTO[/b]")
    if summary.get("training", []).is_empty():
        lines.append("• No hay gladiadores asignados a entrenamiento.")
    else:
        for item in summary.get("training", []):
            lines.append("• %s: %s · +%d progreso · riesgo %d%%" % [item.get("name", "?"), item.get("focus_name", "Entrenamiento"), int(item.get("weekly_gain", 0)), int(item.get("injury_risk", 0))])

    lines.append("\n[b]ESTADO MÉDICO[/b]")
    if summary.get("injured", []).is_empty():
        lines.append("• No hay gladiadores lesionados.")
    else:
        for item in summary.get("injured", []):
            lines.append("• %s: %s · gravedad %d · %d semana(s)" % [item.get("name", "?"), item.get("injury", "Herida"), int(item.get("severity", 1)), int(item.get("weeks", 1))])

    var fight: Dictionary = summary.get("fight", {})
    lines.append("\n[b]ARENA[/b]")
    lines.append("• %s: %s" % ["PENDIENTE" if bool(summary.get("fight_pending", false)) else "Completado o no requerido", fight.get("name", "Combate semanal")])

    lines.append("\n[b]ECONOMÍA PROYECTADA[/b]")
    lines.append("• Ingresos previstos: %d denarios" % int(economy.get("income", 0)))
    lines.append("• Mantenimiento y salarios: %d" % int(economy.get("maintenance_and_wages", 0)))
    lines.append("• Cuotas de préstamos: %d" % int(economy.get("loan_payments", 0)))
    lines.append("• Saldo estimado: %d denarios" % int(summary.get("denarii_after", 0)))
    lines.append("• Comida: %d consumida · %d restante" % [int(summary.get("food_consumption", 0)), int(summary.get("food_after", 0))])

    var blockers: Array = summary.get("blockers", [])
    if not blockers.is_empty():
        lines.append("\n[color=red][b]NO SE PUEDE CERRAR LA SEMANA[/b][/color]")
        for blocker in blockers:
            lines.append("[color=red]• %s[/color]" % str(blocker))
    var warnings: Array = summary.get("warnings", [])
    if not warnings.is_empty():
        lines.append("\n[color=orange][b]ADVERTENCIAS[/b][/color]")
        for warning in warnings:
            lines.append("[color=orange]• %s[/color]" % str(warning))

    content_label.text = "\n".join(lines)
    confirm_button.disabled = not bool(summary.get("can_close", false))
    confirm_button.tooltip_text = "Resolvé los bloqueos indicados antes de avanzar." if confirm_button.disabled else "Procesa la semana y abre la siguiente."

func _confirm() -> void:
    var summary := WeeklyPlanningController.get_summary()
    if not bool(summary.get("can_close", false)):
        _render()
        return
    _close()
    GameState.advance_week()

func _refresh_if_open() -> void:
    if overlay != null and overlay.visible:
        call_deferred("_render")

func _close() -> void:
    if overlay != null:
        overlay.visible = false
