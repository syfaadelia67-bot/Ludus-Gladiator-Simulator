extends Node

const STEPS := [
    {
        "title":"1. Tu ludus",
        "text":"Revisá Personal para conocer gladiadores, esclavos, moral, lealtad y trabajos disponibles.",
        "tab":"Personal"
    },
    {
        "title":"2. Preparación semanal",
        "text":"Asigná trabajos y entrenamiento antes de cerrar la semana. La producción y recuperación se calculan durante siete días internos.",
        "tab":"Personal"
    },
    {
        "title":"3. Mercado y equipo",
        "text":"Usá Mercado, Forja y Equipamiento para reforzar al gladiador que representará al ludus.",
        "tab":"Mercado"
    },
    {
        "title":"4. Evento de campaña",
        "text":"Cada semana presenta una decisión narrativa. Sus consecuencias pueden modificar recursos, relaciones y reputación.",
        "tab":"Eventos"
    },
    {
        "title":"5. Combate semanal",
        "text":"Entrá en Arena, elegí gladiador, táctica y plan de habilidades. Siempre existe al menos una pelea por semana.",
        "tab":"Arena"
    }
]

var panel: PanelContainer
var title_label: Label
var body_label: Label
var progress_label: Label
var current_step := 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    LudusOwnerManager.owner_configured.connect(func(_profile: Dictionary): call_deferred("_show_if_needed"))
    SaveManager.load_completed.connect(func(_path: String): call_deferred("_show_if_needed"))
    call_deferred("_show_if_needed")

func _show_if_needed() -> void:
    if not LudusOwnerManager.should_show_tutorial():
        _hide_panel()
        return
    var scene := get_tree().current_scene
    if scene == null or scene.name != "Main":
        return
    if panel == null or not is_instance_valid(panel):
        _build_panel(scene)
    current_step = clampi(current_step, 0, STEPS.size() - 1)
    panel.visible = true
    _render_step()

func _build_panel(scene: Node) -> void:
    panel = PanelContainer.new()
    panel.name = "CampaignTutorial"
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.position = Vector2(-394, 18)
    panel.size = Vector2(370, 250)
    panel.custom_minimum_size = Vector2(370, 250)
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

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_END
    content.add_child(actions)

    var skip_button := Button.new()
    skip_button.text = "Saltar tutorial"
    skip_button.pressed.connect(_complete_tutorial)
    actions.add_child(skip_button)

    var next_button := Button.new()
    next_button.name = "NextStep"
    next_button.text = "Siguiente"
    next_button.pressed.connect(_next_step)
    actions.add_child(next_button)

func _render_step() -> void:
    var step: Dictionary = STEPS[current_step]
    progress_label.text = "%d/%d" % [current_step + 1, STEPS.size()]
    title_label.text = str(step.get("title", "Tutorial"))
    body_label.text = str(step.get("text", ""))
    var next_button := panel.find_child("NextStep", true, false) as Button
    if next_button != null:
        next_button.text = "Finalizar" if current_step == STEPS.size() - 1 else "Siguiente"
    _focus_tab(str(step.get("tab", "")))

func _focus_tab(tab_name: String) -> void:
    if tab_name.is_empty():
        return
    var scene := get_tree().current_scene
    if scene == null:
        return
    var tabs := scene.find_child("Tabs", true, false) as TabContainer
    if tabs == null:
        return
    for index in range(tabs.get_tab_count()):
        var tab := tabs.get_child(index)
        if tab != null and tab.name == tab_name:
            tabs.current_tab = index
            return

func _next_step() -> void:
    if current_step >= STEPS.size() - 1:
        _complete_tutorial()
        return
    current_step += 1
    _render_step()

func _complete_tutorial() -> void:
    LudusOwnerManager.mark_tutorial_completed()
    SaveManager.save_game()
    _hide_panel()

func _hide_panel() -> void:
    if panel != null and is_instance_valid(panel):
        panel.visible = false
