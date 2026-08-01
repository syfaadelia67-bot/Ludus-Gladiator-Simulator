extends Node

func _ready() -> void:
    DemoEconomyBalanceController.economy_balance_changed.connect(func(): call_deferred("_refresh"))
    call_deferred("_attach")

func _attach() -> void:
    for _attempt in range(90):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null:
            continue
        var panel := scene.find_child("Economía", true, false)
        if panel == null:
            continue
        if panel.get_node_or_null("DemoBalanceAudit") == null:
            var audit := RichTextLabel.new()
            audit.name = "DemoBalanceAudit"
            audit.bbcode_enabled = true
            audit.fit_content = true
            audit.custom_minimum_size = Vector2(0, 280)
            panel.add_child(audit)
            panel.move_child(audit, 0)
        _refresh()
        return

func _refresh() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var label := scene.find_child("DemoBalanceAudit", true, false) as RichTextLabel
    if label == null:
        return
    var audit := DemoEconomyBalanceController.get_audit()
    var lines: Array[String] = []
    lines.append("[font_size=20][b]BALANCE ECONÓMICO DE LA DEMO · %s[/b][/font_size]" % DemoEconomyBalanceController.get_balance_label())
    lines.append("Tesorería: %d denarios · deuda: %d" % [int(audit.get("denarii", 0)), int(audit.get("debt", 0))])
    lines.append("Costo fijo semanal: %d · patrocinio: +%d · préstamos: -%d" % [int(audit.get("weekly_fixed_cost", 0)), int(audit.get("sponsor_income", 0)), int(audit.get("loan_payments", 0))])
    lines.append("Balance previsto antes de Arena y eventos: %+d denarios" % int(audit.get("weekly_net", 0)))
    var runway := int(audit.get("runway_weeks", 99))
    lines.append("Autonomía estimada: %s" % ("estable" if runway >= 99 else "%d semana(s)" % runway))
    lines.append("Comida: %d · consumo siguiente semana: %d" % [int(audit.get("food", 0)), int(audit.get("food_consumption", 0))])
    if not audit.get("blockers", []).is_empty():
        lines.append("\n[color=red][b]BLOQUEOS[/b][/color]")
        for item in audit.get("blockers", []):
            lines.append("• %s" % str(item))
    if not audit.get("warnings", []).is_empty():
        lines.append("\n[color=orange][b]ADVERTENCIAS[/b][/color]")
        for item in audit.get("warnings", []):
            lines.append("• %s" % str(item))
    lines.append("\n[b]PRECIOS CLAVE[/b]")
    var prices: Array = audit.get("key_prices", [])
    for index in range(mini(10, prices.size())):
        var item: Dictionary = prices[index]
        lines.append("%s · %s: %d denarios" % [str(item.get("category", "Costo")), str(item.get("name", "")), int(item.get("price", 0))])
    label.text = "\n".join(lines)
