extends Node

var arena: VBoxContainer
var event_card: RichTextLabel
var energy_selector: OptionButton
var surrender_selector: OptionButton
var finisher_toggle: CheckButton
var technique_selector: OptionButton
var technique_list: RichTextLabel
var loadout_summary: RichTextLabel
var report: RichTextLabel
var speed_selector: OptionButton
var replay_button: Button
var pause_button: Button
var step_button: Button
var skip_button: Button
var action_queue: Array[Dictionary] = []
var selected_techniques: Array[String] = ["basic_attack", "guard", "feint"]
var replay_index: int = 0
var replay_timer: Timer
var replay_paused: bool = false
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
    _refresh_available_techniques()

func _build_interface() -> void:
    var navigation_row := HBoxContainer.new()
    navigation_row.name = "ArenaNavigation"
    arena.add_child(navigation_row)
    arena.move_child(navigation_row, 0)

    var back_button := Button.new()
    back_button.text = "← Volver a Personal"
    back_button.tooltip_text = "Detiene la repetición y vuelve a la administración del ludus."
    back_button.pressed.connect(_leave_arena)
    navigation_row.add_child(back_button)

    var navigation_hint := Label.new()
    navigation_hint.text = "Arena · preparación, combate e informe"
    navigation_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    navigation_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    navigation_row.add_child(navigation_hint)

    event_card = RichTextLabel.new()
    event_card.name = "EventPreparation"
    event_card.bbcode_enabled = true
    event_card.custom_minimum_size = Vector2(0, 86)
    event_card.fit_content = true
    arena.add_child(event_card)
    arena.move_child(event_card, 1)

    var instruction_title := Label.new()
    instruction_title.text = "INSTRUCCIONES PREVIAS"
    arena.add_child(instruction_title)
    arena.move_child(instruction_title, 2)

    var instruction_row := HBoxContainer.new()
    instruction_row.name = "BattleInstructions"
    arena.add_child(instruction_row)
    arena.move_child(instruction_row, 3)

    energy_selector = OptionButton.new()
    energy_selector.add_item("Energía equilibrada")
    energy_selector.add_item("Conservar energía")
    energy_selector.add_item("Gastar energía agresivamente")
    energy_selector.tooltip_text = "Define cuánto arriesga el gladiador con sus técnicas."
    instruction_row.add_child(energy_selector)

    surrender_selector = OptionButton.new()
    surrender_selector.add_item("Rendirse bajo 10%")
    surrender_selector.add_item("Rendirse bajo 20%")
    surrender_selector.add_item("Rendirse bajo 30%")
    surrender_selector.add_item("Nunca rendirse")
    surrender_selector.select(1)
    instruction_row.add_child(surrender_selector)

    finisher_toggle = CheckButton.new()
    finisher_toggle.text = "Permitir ejecución"
    finisher_toggle.button_pressed = true
    finisher_toggle.tooltip_text = "Autoriza remates cuando el rival está muy herido."
    instruction_row.add_child(finisher_toggle)

    loadout_summary = RichTextLabel.new()
    loadout_summary.bbcode_enabled = true
    loadout_summary.fit_content = true
    loadout_summary.custom_minimum_size = Vector2(0, 54)
    arena.add_child(loadout_summary)
    arena.move_child(loadout_summary, 4)

    var technique_row := HBoxContainer.new()
    technique_row.name = "TechniqueLoadout"
    arena.add_child(technique_row)
    arena.move_child(technique_row, 5)

    technique_selector = OptionButton.new()
    technique_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    technique_row.add_child(technique_selector)

    var add_button := Button.new()
    add_button.text = "Equipar técnica"
    add_button.pressed.connect(_add_selected_technique)
    technique_row.add_child(add_button)

    var reset_button := Button.new()
    reset_button.text = "Restablecer"
    reset_button.pressed.connect(_reset_techniques)
    technique_row.add_child(reset_button)

    technique_list = RichTextLabel.new()
    technique_list.bbcode_enabled = true
    technique_list.custom_minimum_size = Vector2(0, 70)
    technique_list.fit_content = true
    arena.add_child(technique_list)
    arena.move_child(technique_list, 6)

    var arena_setup := arena.get_node_or_null("Setup") as HBoxContainer
    if arena_setup != null:
        var gladiator_selector := arena_setup.get_node_or_null("GladiatorSelector") as OptionButton
        if gladiator_selector != null:
            gladiator_selector.item_selected.connect(func(_index: int): _refresh_available_techniques())
        var start_button := arena_setup.get_node_or_null("StartDuel") as Button
        if start_button != null:
            start_button.text = "Preparar y disputar evento"
            start_button.button_down.connect(_configure_battle)

    var playback_row := HBoxContainer.new()
    playback_row.name = "PlaybackControls"
    arena.add_child(playback_row)

    var playback_label := Label.new()
    playback_label.text = "REPETICIÓN"
    playback_row.add_child(playback_label)

    speed_selector = OptionButton.new()
    speed_selector.add_item("Velocidad x1")
    speed_selector.add_item("Velocidad x2")
    speed_selector.add_item("Velocidad x4")
    speed_selector.select(1)
    playback_row.add_child(speed_selector)

    replay_button = Button.new()
    replay_button.text = "Repetir"
    replay_button.disabled = true
    replay_button.pressed.connect(_start_replay)
    playback_row.add_child(replay_button)

    pause_button = Button.new()
    pause_button.text = "Pausar"
    pause_button.disabled = true
    pause_button.pressed.connect(_toggle_pause)
    playback_row.add_child(pause_button)

    step_button = Button.new()
    step_button.text = "Siguiente acción"
    step_button.disabled = true
    step_button.pressed.connect(_step_replay)
    playback_row.add_child(step_button)

    skip_button = Button.new()
    skip_button.text = "Saltar al resultado"
    skip_button.disabled = true
    skip_button.pressed.connect(_skip_to_result)
    playback_row.add_child(skip_button)

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
    EquipmentManager.equipment_changed.connect(func(_person_id: String): _refresh_available_techniques())
    RosterManager.roster_changed.connect(_refresh_available_techniques)

func _leave_arena() -> void:
    replay_timer.stop()
    replay_paused = false
    var tabs := arena.get_parent() as TabContainer
    if tabs != null:
        var personal_index := tabs.get_tab_idx_from_control(tabs.get_node_or_null("Personal"))
        if personal_index >= 0:
            tabs.current_tab = personal_index

func _selected_gladiator():
    var selector := arena.get_node_or_null("Setup/GladiatorSelector") as OptionButton
    if selector == null or selector.selected < 0:
        return null
    var selected_text := selector.get_item_text(selector.selected)
    for person in RosterManager.get_people():
        if person.role == "gladiator" and selected_text.begins_with(person.display_name):
            return person
    return null

func _refresh_available_techniques() -> void:
    if technique_selector == null:
        return
    var fighter = _selected_gladiator()
    var allowed: Array[String] = EquipmentManager.get_allowed_combat_techniques(fighter)
    technique_selector.clear()
    for technique_id in CombatManager.get_technique_ids():
        var data: Dictionary = CombatManager.get_technique(technique_id)
        var available: bool = allowed.has(technique_id)
        var label := "%s — %s" % [data.get("name", technique_id), data.get("description", "")]
        if not available:
            label += " [BLOQUEADA: %s]" % EquipmentManager.get_technique_requirement(technique_id)
        technique_selector.add_item(label)
        var item_index := technique_selector.item_count - 1
        technique_selector.set_item_metadata(item_index, technique_id)
        technique_selector.set_item_disabled(item_index, not available)

    var valid_selection: Array[String] = []
    for technique_id in selected_techniques:
        if allowed.has(technique_id):
            valid_selection.append(technique_id)
    if not valid_selection.has("basic_attack"):
        valid_selection.push_front("basic_attack")
    selected_techniques = valid_selection.slice(0, 5)

    if fighter == null:
        loadout_summary.text = "[b]Equipamiento de combate[/b]\nSeleccioná un gladiador para ver técnicas disponibles."
    else:
        var loadout: Dictionary = EquipmentManager.get_equipped_loadout(fighter)
        loadout_summary.text = "[b]Equipamiento de %s[/b]\nArma: %s | Armadura: %s | Escudo: %s" % [fighter.display_name, loadout.get("weapon_name", "Ninguno"), loadout.get("armor_name", "Ninguna"), loadout.get("shield_name", "Ninguno")]
    _refresh_technique_list()

func _configure_battle() -> void:
    _refresh_available_techniques()
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
    if technique_selector.selected < 0 or technique_selector.is_item_disabled(technique_selector.selected):
        return
    var technique_id := str(technique_selector.get_item_metadata(technique_selector.selected))
    if selected_techniques.has(technique_id):
        selected_techniques.erase(technique_id)
    selected_techniques.append(technique_id)
    while selected_techniques.size() > 5:
        selected_techniques.pop_front()
    if not selected_techniques.has("basic_attack"):
        selected_techniques.push_front("basic_attack")
    _refresh_technique_list()

func _reset_techniques() -> void:
    selected_techniques = ["basic_attack", "guard", "feint"]
    _refresh_available_techniques()

func _refresh_technique_list() -> void:
    if technique_list == null:
        return
    var lines: Array[String] = ["[b]Técnicas equipadas (máximo 5)[/b]"]
    for technique_id in selected_techniques:
        var data: Dictionary = CombatManager.get_technique(technique_id)
        lines.append("• %s — energía %d, recarga %d" % [data.get("name", technique_id), int(data.get("energy", 0)), int(data.get("cooldown", 0))])
    lines.append("[i]Las técnicas especiales dependen del arma y el escudo equipados.[/i]")
    technique_list.text = "\n".join(lines)

func _refresh_event() -> void:
    if event_card == null:
        return
    var data: Dictionary = CombatManager.get_current_event_details()
    event_card.text = "[b]%s[/b]\n%s\nRiesgo: %s | Recompensa: %s" % [data.get("name", "Arena"), data.get("rules", ""), data.get("risk", ""), data.get("reward", "")]

func _on_combat_finished(result: Dictionary) -> void:
    last_result = result.duplicate(true)
    action_queue.assign(result.get("actions", []))
    var has_actions := not action_queue.is_empty()
    replay_button.disabled = not has_actions
    pause_button.disabled = not has_actions
    step_button.disabled = not has_actions
    skip_button.disabled = not has_actions
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
    replay_paused = false
    pause_button.text = "Pausar"
    var combat_log := arena.get_node_or_null("CombatLog") as RichTextLabel
    if combat_log != null:
        combat_log.clear()
        combat_log.append_text("[b]Combate por turnos[/b]\n")
    _play_next_action()

func _toggle_pause() -> void:
    replay_paused = not replay_paused
    replay_timer.stop()
    pause_button.text = "Continuar" if replay_paused else "Pausar"
    if not replay_paused and replay_index < action_queue.size():
        _schedule_next_action()

func _step_replay() -> void:
    replay_paused = true
    replay_timer.stop()
    pause_button.text = "Continuar"
    _play_next_action()

func _skip_to_result() -> void:
    replay_timer.stop()
    replay_paused = true
    pause_button.text = "Continuar"
    if action_queue.is_empty():
        return
    replay_index = action_queue.size() - 1
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
    if replay_index < action_queue.size() and not replay_paused:
        _schedule_next_action()

func _schedule_next_action() -> void:
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
    var status_stats: Dictionary = result.get("status_stats", {})
    if not status_stats.is_empty():
        lines.append("[b]Estados aplicados[/b]")
        for status_name in status_stats.keys():
            lines.append("• %s: %d" % [str(status_name).capitalize(), int(status_stats.get(status_name, 0))])
    report.text = "\n".join(lines)
