extends Node

var arena: VBoxContainer
var event_card: RichTextLabel
var instructions_row: HBoxContainer
var energy_selector: OptionButton
var surrender_selector: OptionButton
var finisher_toggle: CheckButton
var technique_selector: OptionButton
var technique_list: RichTextLabel
var report: RichTextLabel
var speed_selector: OptionButton
var replay_button: Button
var action_queue: Array[Dictionary] = []
var selected_techniques: Array[String] = ["basic_attack", "guard", "feint", "lunge", "shield_bash"]
var replay_index: int = 0
var replay_timer: Timer
var last_result: Dictionary = {}

func setup(target_arena: VBoxContainer) -> void:
    arena = target_arena
    if arena == null or arena.has_meta("enhanced_combat_ui"):
        queue_free()
        return
    arena.set_meta("enhanced_combat_ui", true)
    _build_interface()
    _connect_signals()
    _refresh_event()

func _build_interface() -> void:
    event_card = RichTextLabel.new()
    event_card.name = "EventPreparation"
    event_card.bbcode_enabled = true
    event_card.custom_minimum_size = Vector2(0, 86)
    event_card.fit_content = true
    arena.add_child(event_card)
    arena.move_child(event_card, 0)

    var instruction_title := Label.new()
    instruction_title.text = "INSTRUCCIONES PREVIAS"
    arena.add_child(instruction_title)
    arena.move_child(instruction_title, 1)

    instructions_row = HBoxContainer.new()
    instructions_row.name = "BattleInstructions"
    arena.add_child(instructions_row)
    arena.move_child(instructions_row, 2)

    energy_selector = OptionButton.new()
    energy_selector.tooltip_text = "Define cuánto arriesga el gladiador con sus técnicas."
    energy_selector.add_item("Energía equilibrada")
    energy_selector.add_item("Conservar energía")
    energy_selector.add_item("Gastar energía agresivamente")
    instructions_row.add_child(energy_selector)

    surrender_selector = OptionButton.new()
    surrender_selector.tooltip_text = "Porcentaje de vida bajo el cual puede rendirse."
    surrender_selector.add_item("Rendirse bajo 10%")
    surrender_selector.add_item("Rendirse bajo 20%")
    surrender_selector.add_item("Rendirse bajo 30%")
    surrender_selector.add_item("Nunca rendirse")
    surrender_selector.select(1)
    instructions_row.add_child(surrender_selector)

    finisher_toggle = CheckButton.new()
    finisher_toggle.text = "Permitir ejecución"
    finisher_toggle.button_pressed = true
    finisher_toggle.tooltip_text = "Autoriza técnicas de remate cuando el rival está muy herido."
    instructions_row.add_child(finisher_toggle)

    var technique_row := HBoxContainer.new()
    technique_row.name = "TechniqueLoadout"
    arena.add_child(technique_row)
    arena.move_child(technique_row, 3)

    technique_selector = OptionButton.new()
    technique_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for technique_id in CombatManager.get_technique_ids():
        var data: Dictionary = CombatManager.get_technique(technique_id)
        technique_selector.add_item("%s — %s" % [data.get("name", technique_id), data.get("description", "")])
        technique_selector.set_item_metadata(technique_selector.item_count - 1, technique_id)
    technique_row.add_child(technique_selector)

    var add_button := Button.new()
    add_button.text = "Equipar técnica"
    add_button.pressed.connect(_add_selected_technique)
    technique_row.add_child(add_button)

    var clear_button := Button.new()
    clear_button.text = "Restablecer"
    clear_button.pressed.connect(_reset_techniques)
    technique_row.add_child(clear_button)

    technique_list = RichTextLabel.new()
    technique_list.bbcode_enabled = true
    technique_list.custom_minimum_size = Vector2(0, 62)
    technique_list.fit_content = true
    arena.add_child(technique_list)
    arena.move_child(technique_list, 4)
    _refresh_technique_list()

    var setup := arena.get_node_or_null("Setup")
    if setup is HBoxContainer:
        var event_label := Label.new()
        event_label.text = "Combatiente / táctica"
        setup.add_child(event_label)
        setup.move_child(event_label, 0)
        var start_button := setup.get_node_or_null("StartDuel")
        if start_button is Button:
            start_button.text = "Preparar y disputar evento"
            start_button.button_down.connect(_configure_battle)

    var playback_row := HBoxContainer.new()
    playback_row.name = "PlaybackControls"
    arena.add_child(playback_row)
    var playback_label := Label.new()
    playback_label.text = "REPETICIÓN DEL COMBATE"
    playback_row.add_child(playback_label)
    speed_selector = OptionButton.new()
    speed_selector.add_item("Velocidad x1")
    speed_selector.add_item("Velocidad x2")
    speed_selector.add_item("Velocidad x4")
    speed_selector.select(1)
    playback_row.add_child(speed_selector)
    replay_button = Button.new()
    replay_button.text = "Repetir combate"
    replay_button.disabled = true
    replay_button.pressed.connect(_start_replay)
    playback_row.add_child(replay_button)

    report = RichTextLabel.new()
    report.name = "BattleReport"
    report.bbcode_enabled = true
    report.custom_minimum_size = Vector2(0, 145)
    report.scroll_following = true
    report.text = "[b]Informe[/b]\nTodavía no se disputó un combate."
    arena.add_child(report)

    replay_timer = Timer.new()
    replay_timer.one_shot = true
    replay_timer.timeout.connect(_play_next_action)
    add_child(replay_timer)

func _connect_signals() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    CombatManager.combat_failed.connect(_on_combat_failed)
    GameState.day_advanced.connect(func(_day: int): _refresh_event())

func _configure_battle() -> void:
    var energy_rule := "balanced"
    if energy_selector.selected == 1:
        energy_rule = "conserve"
    elif energy_selector.selected == 2:
        energy_rule = "spend"
    var surrender_threshold := 20
    match surrender_selector.selected:
        0: surrender_threshold = 10
        1: surrender_threshold = 20
        2: surrender_threshold = 30
        3: surrender_threshold = 0
    CombatManager.configure_next_battle({
        "energy_rule": energy_rule,
        "surrender_threshold": surrender_threshold,
        "allow_finisher": finisher_toggle.button_pressed,
        "techniques": selected_techniques
    })

func _add_selected_technique() -> void:
    if technique_selector.selected < 0:
        return
    var technique_id := str(technique_selector.get_item_metadata(technique_selector.selected))
    if selected_techniques.has(technique_id):
        selected_techniques.erase(technique_id)
    selected_techniques.append(technique_id)
    while selected_techniques.size() > 5:
        selected_techniques.pop_front()
    if not selected_techniques.has("basic_attack"):
        selected_techniques.push_front("basic_attack")
        if selected_techniques.size() > 5:
            selected_techniques.pop_back()
    _refresh_technique_list()

func _reset_techniques() -> void:
    selected_techniques = ["basic_attack", "guard", "feint", "lunge", "shield_bash"]
    _refresh_technique_list()

func _refresh_technique_list() -> void:
    var lines: Array[String] = ["[b]Técnicas equipadas (máximo 5)[/b]"]
    for technique_id in selected_techniques:
        var data: Dictionary = CombatManager.get_technique(technique_id)
        lines.append("• %s — energía %d, recarga %d" % [data.get("name", technique_id), int(data.get("energy", 0)), int(data.get("cooldown", 0))])
    technique_list.text = "\n".join(lines)

func _refresh_event() -> void:
    var data: Dictionary = CombatManager.get_current_event_details()
    event_card.text = "[b]%s[/b]\n%s\nRiesgo: %s | Recompensa: %s" % [data.get("name", "Arena"), data.get("rules", ""), data.get("risk", ""), data.get("reward", "")]

func _on_combat_finished(result: Dictionary) -> void:
    last_result = result.duplicate(true)
    action_queue.assign(result.get("actions", []))
    replay_button.disabled = action_queue.is_empty()
    _render_report(result)
    _start_replay()

func _on_combat_failed(reason: String) -> void:
    report.text = "[color=orange][b]No se pudo disputar el combate[/b][/color]\n%s" % reason
    _refresh_event()

func _start_replay() -> void:
    if action_queue.is_empty():
        return
    replay_timer.stop()
    replay_index = 0
    var combat_log := arena.get_node_or_null("CombatLog") as RichTextLabel
    if combat_log != null:
        combat_log.clear()
        combat_log.append_text("[b]Combate por turnos[/b]\n")
    _play_next_action()

func _play_next_action() -> void:
    if replay_index >= action_queue.size():
        return
    var action: Dictionary = action_queue[replay_index]
    replay_index += 1
    _apply_snapshot(action)
    var combat_log := arena.get_node_or_null("CombatLog") as RichTextLabel
    if combat_log != null:
        combat_log.append_text("%s\n" % str(action.get("text", "")))
    var result_label := arena.get_node_or_null("Result") as Label
    if result_label != null:
        result_label.text = str(action.get("text", ""))
    if replay_index < action_queue.size():
        var delay := 0.78
        if speed_selector.selected == 1:
            delay = 0.38
        elif speed_selector.selected == 2:
            delay = 0.16
        replay_timer.start(delay)

func _apply_snapshot(action: Dictionary) -> void:
    _set_bar("Stage/PlayerCard/Health", int(action.get("player_health", 0)), int(action.get("player_max_health", 1)))
    _set_bar("Stage/PlayerCard/Energy", int(action.get("player_energy", 0)), int(action.get("player_max_energy", 1)))
    _set_bar("Stage/EnemyCard/Health", int(action.get("enemy_health", 0)), int(action.get("enemy_max_health", 1)))
    _set_bar("Stage/EnemyCard/Energy", int(action.get("enemy_energy", 0)), int(action.get("enemy_max_energy", 1)))
    var player_body := arena.get_node_or_null("Stage/PlayerCard/Body") as ColorRect
    var enemy_body := arena.get_node_or_null("Stage/EnemyCard/Body") as ColorRect
    if player_body != null:
        player_body.modulate = Color(1.25, 1.25, 1.25) if str(action.get("actor", "")) == "player" else Color.WHITE
    if enemy_body != null:
        enemy_body.modulate = Color(1.25, 1.25, 1.25) if str(action.get("actor", "")) == "enemy" else Color.WHITE

func _set_bar(path: String, value: int, maximum: int) -> void:
    var bar := arena.get_node_or_null(NodePath(path)) as ProgressBar
    if bar == null:
        return
    bar.max_value = maxi(1, maximum)
    bar.value = clampi(value, 0, maxi(1, maximum))
    bar.tooltip_text = "%d/%d" % [value, maximum]

func _render_report(result: Dictionary) -> void:
    var status := "VICTORIA" if bool(result.get("victory", false)) else ("RENDICIÓN" if bool(result.get("surrendered", false)) else "DERROTA")
    var lines: Array[String] = [
        "[b]INFORME POSTERIOR[/b]",
        "%s — %s" % [result.get("event_name", "Arena"), status],
        "Rondas: %d | Premio: %d denarios | Reputación: %+d" % [int(result.get("rounds", 0)), int(result.get("reward", 0)), int(result.get("reputation", 0))]
    ]
    var injury := str(result.get("injury", ""))
    lines.append("Herida: %s" % (injury if not injury.is_empty() else "Ninguna"))
    lines.append("[b]Uso de técnicas[/b]")
    var stats: Dictionary = result.get("technique_stats", {})
    if stats.is_empty():
        lines.append("Sin datos de técnicas.")
    else:
        for value in stats.values():
            var item: Dictionary = value
            lines.append("• %s: %d uso(s), %d daño" % [item.get("name", "Técnica"), int(item.get("uses", 0)), int(item.get("damage", 0))])
    report.text = "\n".join(lines)
