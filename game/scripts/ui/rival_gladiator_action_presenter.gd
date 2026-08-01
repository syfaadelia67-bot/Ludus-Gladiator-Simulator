extends Node

var selected_id := ""
var selector: OptionButton
var details: RichTextLabel
var result_label: Label

func _ready() -> void:
    RivalManager.rivals_changed.connect(func(): call_deferred("_refresh"))
    RivalGladiatorActionController.rival_gladiator_action_completed.connect(_on_result)
    RivalGladiatorActionController.rival_gladiator_action_failed.connect(func(reason: String): _show_result(reason))
    call_deferred("_attach")

func _attach() -> void:
    for _attempt in range(90):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null:
            continue
        var panel := scene.find_child("Rivales", true, false)
        if panel == null or panel.get_node_or_null("UniqueGladiatorActions") != null:
            continue
        var section := VBoxContainer.new()
        section.name = "UniqueGladiatorActions"
        panel.add_child(section)
        var title := Label.new()
        title.text = "GLADIADORES ÚNICOS DE CASAS RIVALES"
        title.add_theme_font_size_override("font_size", 18)
        section.add_child(title)
        selector = OptionButton.new()
        selector.item_selected.connect(_on_selected)
        section.add_child(selector)
        details = RichTextLabel.new()
        details.bbcode_enabled = true
        details.fit_content = true
        details.custom_minimum_size = Vector2(0, 145)
        section.add_child(details)
        var actions := HBoxContainer.new()
        section.add_child(actions)
        var undermine := Button.new()
        undermine.text = "Reducir lealtad · 10 intel / 45 denarios"
        undermine.pressed.connect(func(): RivalGladiatorActionController.undermine_loyalty(selected_id))
        actions.add_child(undermine)
        var sabotage := Button.new()
        sabotage.text = "Sabotear entrenamiento · 16 intel / 70 denarios"
        sabotage.pressed.connect(func(): RivalGladiatorActionController.sabotage_training(selected_id))
        actions.add_child(sabotage)
        var contract := Button.new()
        contract.text = "Comprar contrato"
        contract.pressed.connect(func(): RivalGladiatorActionController.contract_gladiator(selected_id))
        actions.add_child(contract)
        result_label = Label.new()
        result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        section.add_child(result_label)
        _refresh()
        return

func _refresh() -> void:
    if selector == null or not is_instance_valid(selector):
        return
    var profiles := RivalGladiatorActionController.get_rival_gladiators()
    selector.clear()
    for profile in profiles:
        selector.add_item("%s · %s" % [str(profile.get("name", "Gladiador")), str(profile.get("rival_name", "Casa rival"))])
        selector.set_item_metadata(selector.item_count - 1, str(profile.get("gladiator_id", "")))
    if profiles.is_empty():
        selected_id = ""
        details.text = "No hay gladiadores únicos bajo control rival."
        return
    var index := 0
    for i in range(selector.item_count):
        if str(selector.get_item_metadata(i)) == selected_id:
            index = i
            break
    selector.select(index)
    selected_id = str(selector.get_item_metadata(index))
    _refresh_details()

func _on_selected(index: int) -> void:
    selected_id = str(selector.get_item_metadata(index))
    _refresh_details()

func _refresh_details() -> void:
    if details == null:
        return
    for profile in RivalGladiatorActionController.get_rival_gladiators():
        if str(profile.get("gladiator_id", "")) != selected_id:
            continue
        var visible: Dictionary = profile.get("visible", {})
        var lines := [
            "[b]%s[/b] · %s" % [str(profile.get("name", "Gladiador")), str(profile.get("origin", ""))],
            "Casa: %s · nivel observado: %d" % [str(profile.get("rival_name", "Casa rival")), int(visible.get("level", 1))],
            "Lealtad estimada: %s" % str(visible.get("loyalty_band", "desconocida")),
            "Inteligencia sobre la casa: %d/100" % int(profile.get("intel_level", 0))
        ]
        if visible.has("wins"):
            lines.append("Récord conocido: %d-%d · progreso %s" % [int(visible.get("wins", 0)), int(visible.get("losses", 0)), str(visible.get("experience_band", "desconocido"))])
        if visible.has("loyalty"):
            lines.append("Lealtad exacta: %d · contrato estimado: %d denarios" % [int(visible.get("loyalty", 0)), int(visible.get("contract_price", 0))])
        else:
            lines.append("Con 45 de inteligencia se revelan lealtad y precio exactos.")
        details.text = "\n".join(lines)
        return

func _on_result(result: Dictionary) -> void:
    _show_result(str(result.get("message", "Operación completada.")))
    call_deferred("_refresh")

func _show_result(message: String) -> void:
    if result_label != null and is_instance_valid(result_label):
        result_label.text = message
