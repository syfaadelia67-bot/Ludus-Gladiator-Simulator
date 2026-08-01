extends Node

const STEPS := [
    {
        "id":"inspect_roster",
        "title":"1. Tu ludus",
        "text":"La finca es el centro del ludus. Desde aquí se abren el personal, el mercado, la forja, los eventos y la arena.",
        "system":"finca",
        "objective":"Desde la finca, abrí Personal para revisar gladiadores, esclavos, moral, lealtad y trabajos."
    },
    {
        "id":"advance_week",
        "title":"2. Preparación semanal",
        "text":"Asigná trabajos y entrenamiento antes de cerrar la semana. La producción y recuperación se calculan durante siete días internos.",
        "system":"personal",
        "objective":"Cerrá una semana para procesar trabajos, consumo y recuperación."
    },
    {
        "id":"obtain_equipment",
        "title":"3. Mercado y equipo",
        "text":"Usá Mercado y Forja para reforzar al gladiador que representará al ludus.",
        "system":"mercado",
        "objective":"Comprá personal o fabricá una pieza de equipo."
    },
    {
        "id":"resolve_event",
        "title":"4. Evento de campaña",
        "text":"Cada semana presenta una decisión narrativa. Sus consecuencias pueden modificar recursos, relaciones y reputación.",
        "system":"campana",
        "objective":"Resolvé una decisión narrativa semanal."
    },
    {
        "id":"weekly_combat",
        "title":"5. Combate semanal",
        "text":"Entrá en Arena, elegí gladiador, táctica y plan de habilidades. Siempre existe al menos una pelea por semana.",
        "system":"arena",
        "objective":"Disputá la pelea programada de la semana."
    }
]

var panel: PanelContainer
var title_label: Label
var body_label: Label
var objective_label: Label
var progress_label: Label
var action_button: Button
var current_step := 0
var completed_objectives: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    LudusOwnerManager.owner_configured.connect(func(_profile: Dictionary): call_deferred("_show_if_needed"))
    SaveManager.load_completed.connect(func(_path: String): call_deferred("_show_if_needed"))
    GameState.week_advanced.connect(func(_week: int): _mark_objective("advance_week"))
    MarketManager.purchase_completed.connect(func(_name: String, _price: int): _mark_objective("obtain_equipment"))
    EquipmentManager.craft_completed.connect(func(_name: String, _ore: int, _denarii: int): _mark_objective("obtain_equipment"))
    EventManager.events_changed.connect(_check_event_resolution)
    CombatManager.combat_finished.connect(func(_result: Dictionary): _mark_objective("weekly_combat"))
    FincaHubController.system_opened.connect(_on_system_opened)
    call_deferred("_show_if_needed")

func _show_if_needed() -> void:
    if not LudusOwnerManager.should_show_tutorial():
        _hide_panel()
        return
    var scene := get_tree().current_scene
    if scene == null or scene.name != "Main":
        return
    _restore_progress()
    if current_step == 0:
        FincaHubController.show_finca()
    if panel == null or not is_instance_valid(panel):
        _build_panel(scene)
    panel.visible = true
    _render_step()

func _restore_progress() -> void:
    var progress: Dictionary = LudusOwnerManager.get_tutorial_progress()
    current_step = clampi(int(progress.get("current_step", 0)), 0, STEPS.size() - 1)
    var loaded_objectives: Variant = progress.get("completed_objectives", {})
    completed_objectives = loaded_objectives.duplicate(true) if loaded_objectives is Dictionary else {}

func _persist_progress() -> void:
    LudusOwnerManager.update_tutorial_progress(current_step, completed_objectives)

func _build_panel(scene: Node) -> void:
    panel = PanelContainer.new()
    panel.name = "CampaignTutorial"
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.position = Vector2(-414, 18)
    panel.size = Vector2(390, 300)
    panel.custom_minimum_size = Vector2(390, 300)
    panel.z_index = 80
    scene.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_bottom", 16)
    panel.add_child(margin)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    margin.add_child(content)

    progress_label = Label.new()
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(progress_label)

    title_label = Label.new()
    title_label.add_theme_font_size_override("font_size", 21)
    content.add_child(title_label)

    body_label = Label.new()
    body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(body_label)

    objective_label = Label.new()
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(objective_label)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_END
    content.add_child(actions)

    var skip_button := Button.new()
    skip_button.text = "Saltar tutorial"
    skip_button.pressed.connect(_complete_tutorial)
    actions.add_child(skip_button)

    action_button = Button.new()
    action_button.name = "ObjectiveAction"
    action_button.pressed.connect(_on_action_pressed)
    actions.add_child(action_button)

func _render_step() -> void:
    var step: Dictionary = STEPS[current_step]
    var objective_id := str(step.get("id", ""))
    var completed := bool(completed_objectives.get(objective_id, false))
    progress_label.text = "%d/%d" % [current_step + 1, STEPS.size()]
    title_label.text = str(step.get("title", "Tutorial"))
    body_label.text = str(step.get("text", ""))
    objective_label.text = ("✓ " if completed else "Objetivo: ") + str(step.get("objective", ""))
    if objective_id == "inspect_roster" and not completed:
        action_button.text = "Abrir Personal"
        action_button.disabled = false
    else:
        action_button.text = "Finalizar" if current_step == STEPS.size() - 1 else "Continuar"
        action_button.disabled = not completed
    if not completed:
        _focus_system(str(step.get("system", "")))

func _focus_system(system_id: String) -> void:
    if system_id.is_empty():
        return
    FincaHubController.open_system(system_id)

func _on_system_opened(system_id: String) -> void:
    if current_step < STEPS.size() and str(STEPS[current_step].get("id", "")) == "inspect_roster" and system_id == "personal":
        _mark_objective("inspect_roster")

func _on_action_pressed() -> void:
    var objective_id := str(STEPS[current_step].get("id", ""))
    if objective_id == "inspect_roster" and not bool(completed_objectives.get(objective_id, false)):
        FincaHubController.open_system("personal")
        return
    if not bool(completed_objectives.get(objective_id, false)):
        return
    if current_step >= STEPS.size() - 1:
        _complete_tutorial()
        return
    current_step += 1
    _persist_progress()
    _render_step()

func _mark_objective(objective_id: String) -> void:
    if objective_id.is_empty() or bool(completed_objectives.get(objective_id, false)):
        return
    completed_objectives[objective_id] = true
    _persist_progress()
    if panel != null and is_instance_valid(panel) and current_step < STEPS.size():
        _render_step()

func _check_event_resolution() -> void:
    var state: Dictionary = EventManager.export_state()
    var history: Array = state.get("history", [])
    if not history.is_empty():
        _mark_objective("resolve_event")

func _complete_tutorial() -> void:
    LudusOwnerManager.mark_tutorial_completed()
    SaveManager.save_game()
    _hide_panel()

func _hide_panel() -> void:
    if panel != null and is_instance_valid(panel):
        panel.visible = false
