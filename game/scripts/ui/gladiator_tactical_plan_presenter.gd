extends Node

const CONDITION_LABELS := {
    "always": "Siempre",
    "opening": "Al inicio del combate",
    "target_vulnerable": "Rival vulnerable",
    "target_guarding": "Rival defendiendo",
    "target_low_energy": "Rival con poca energía",
    "self_low_health": "Con poca vida",
    "self_low_energy": "Con poca energía",
    "after_defense": "Después de defender"
}

var selected_person_id := ""
var rows: Array[Dictionary] = []
var feedback: Label

func _ready() -> void:
    GladiatorProgressionManager.progression_changed.connect(func(): call_deferred("_refresh"))
    call_deferred("_attach")

func _attach() -> void:
    for _attempt in range(90):
        await get_tree().process_frame
        var scene := get_tree().current_scene
        if scene == null:
            continue
        var dossier := scene.get_node_or_null("GladiatorDossier")
        if dossier == null:
            continue
        var tabs := dossier.find_child("TabContainer", true, false) as TabContainer
        if tabs == null:
            continue
        if not tabs.tab_changed.is_connected(_on_tab_changed.bind(tabs)):
            tabs.tab_changed.connect(_on_tab_changed.bind(tabs))
        _refresh_from_tabs(tabs)
        return

func _on_tab_changed(_index: int, tabs: TabContainer) -> void:
    _refresh_from_tabs(tabs)

func _refresh_from_tabs(tabs: TabContainer) -> void:
    if not is_instance_valid(tabs):
        return
    var abilities_tab := tabs.find_child("Habilidades", false, false)
    if abilities_tab == null:
        return
    selected_person_id = str(GladiatorDossierPresenter.selected_person_id)
    if selected_person_id.is_empty():
        return
    var box := abilities_tab.get_child(0) if abilities_tab.get_child_count() > 0 else null
    if box == null:
        return
    var existing := box.get_node_or_null("TacticalPlanSection")
    if existing != null:
        existing.queue_free()
    var section := VBoxContainer.new()
    section.name = "TacticalPlanSection"
    section.add_theme_constant_override("separation", 6)
    box.add_child(section)

    var title := Label.new()
    title.text = "PLAN TÁCTICO"
    title.add_theme_font_size_override("font_size", 18)
    section.add_child(title)

    var explanation := Label.new()
    explanation.text = "Configurá hasta cuatro órdenes. Se evalúan de arriba hacia abajo; la primera condición válida ejecuta su habilidad."
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    section.add_child(explanation)

    rows.clear()
    var current_plan := GladiatorProgressionManager.get_tactical_plan(selected_person_id)
    for index in range(4):
        _add_order_row(section, index, current_plan[index] if index < current_plan.size() else {})

    var actions := HBoxContainer.new()
    section.add_child(actions)
    var save_button := Button.new()
    save_button.text = "Guardar plan táctico"
    save_button.pressed.connect(_save_plan)
    actions.add_child(save_button)
    var clear_button := Button.new()
    clear_button.text = "Limpiar"
    clear_button.pressed.connect(_clear_plan)
    actions.add_child(clear_button)

    feedback = Label.new()
    feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    section.add_child(feedback)
    _refresh()

func _add_order_row(parent: VBoxContainer, index: int, order: Dictionary) -> void:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var priority := Label.new()
    priority.text = "%d." % (index + 1)
    priority.custom_minimum_size.x = 28
    row.add_child(priority)

    var ability_selector := OptionButton.new()
    ability_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ability_selector.add_item("Sin orden")
    ability_selector.set_item_metadata(0, "")
    var learned: Dictionary = GladiatorProgressionManager.get_record(selected_person_id).get("abilities", {})
    var ability_ids: Array[String] = []
    for raw_id in learned.keys():
        if int(learned[raw_id]) > 0:
            ability_ids.append(str(raw_id))
    ability_ids.sort()
    for ability_id in ability_ids:
        var data: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
        ability_selector.add_item("%s · Nv. %d" % [data.get("name", ability_id), int(learned[ability_id])])
        ability_selector.set_item_metadata(ability_selector.item_count - 1, ability_id)
        if ability_id == str(order.get("ability_id", "")):
            ability_selector.select(ability_selector.item_count - 1)
    row.add_child(ability_selector)

    var condition_selector := OptionButton.new()
    condition_selector.custom_minimum_size.x = 220
    for condition_id in GladiatorProgressionManager.VALID_TACTICAL_CONDITIONS:
        condition_selector.add_item(str(CONDITION_LABELS.get(condition_id, condition_id)))
        condition_selector.set_item_metadata(condition_selector.item_count - 1, condition_id)
        if condition_id == str(order.get("condition", "always")):
            condition_selector.select(condition_selector.item_count - 1)
    row.add_child(condition_selector)
    rows.append({"ability": ability_selector, "condition": condition_selector})

func _save_plan() -> void:
    var plan: Array = []
    var seen: Dictionary = {}
    for row in rows:
        var ability_selector: OptionButton = row["ability"]
        var condition_selector: OptionButton = row["condition"]
        var ability_id := str(ability_selector.get_item_metadata(ability_selector.selected))
        if ability_id.is_empty():
            continue
        if seen.has(ability_id):
            feedback.text = "Una misma habilidad no puede repetirse en el plan."
            return
        seen[ability_id] = true
        plan.append({
            "ability_id": ability_id,
            "condition": str(condition_selector.get_item_metadata(condition_selector.selected))
        })
    if GladiatorProgressionManager.set_tactical_plan(selected_person_id, plan):
        feedback.text = "Plan táctico guardado: %d orden(es)." % plan.size()
    else:
        feedback.text = "No se pudo guardar. Revisá que todas las habilidades estén aprendidas."

func _clear_plan() -> void:
    if GladiatorProgressionManager.set_tactical_plan(selected_person_id, []):
        feedback.text = "Plan táctico eliminado. El gladiador usará decisiones básicas."
        call_deferred("_rebuild_current")

func _rebuild_current() -> void:
    var dossier := get_tree().current_scene.get_node_or_null("GladiatorDossier") if get_tree().current_scene != null else null
    if dossier == null:
        return
    var tabs := dossier.find_child("TabContainer", true, false) as TabContainer
    if tabs != null:
        _refresh_from_tabs(tabs)

func _refresh() -> void:
    if selected_person_id.is_empty() or feedback == null or not is_instance_valid(feedback):
        return
    var plan := GladiatorProgressionManager.get_tactical_plan(selected_person_id)
    feedback.text = "Plan actual: %d/4 órdenes configuradas." % plan.size()
