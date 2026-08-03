extends Node

const TACTICAL_CONDITIONS := {
    "always":"Siempre",
    "opening":"Inicio del combate",
    "target_vulnerable":"Rival vulnerable",
    "target_defending":"Rival defendiendo",
    "target_low_energy":"Rival con poca energía",
    "self_low_health":"Vida propia menor al 35%",
    "self_low_energy":"Energía propia baja",
    "after_dodge_or_block":"Después de esquivar o bloquear"
}
const MAX_TACTICAL_ORDERS := 4

var arena: VBoxContainer
var navigation: HBoxContainer
var scroll: ScrollContainer
var content: VBoxContainer
var event_card: RichTextLabel
var energy_selector: OptionButton
var surrender_selector: OptionButton
var finisher_toggle: CheckButton
var ability_selector: OptionButton
var condition_selector: OptionButton
var tactical_plan_list: RichTextLabel
var loadout_summary: RichTextLabel
var report: RichTextLabel
var speed_selector: OptionButton
var replay_button: Button
var pause_button: Button
var step_button: Button
var skip_button: Button
var draft_plan: Array[Dictionary] = []
var action_queue: Array[Dictionary] = []
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
    _build_scroll_layout()
    _disconnect_legacy_combat_result_handler()
    _build_interface()
    _connect_signals()
    _refresh_event()
    _refresh_tactical_editor()

func _build_scroll_layout() -> void:
    navigation = arena.get_node_or_null("ArenaNavigation") as HBoxContainer
    if navigation == null:
        navigation = HBoxContainer.new()
        navigation.name = "ArenaNavigation"
        arena.add_child(navigation)
    navigation.custom_minimum_size.y = 44.0

    scroll = arena.get_node_or_null("ArenaScroll") as ScrollContainer
    if scroll == null:
        scroll = ScrollContainer.new()
        scroll.name = "ArenaScroll"
        scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        arena.add_child(scroll)

    content = scroll.get_node_or_null("ArenaContent") as VBoxContainer
    if content == null:
        content = VBoxContainer.new()
        content.name = "ArenaContent"
        content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content.add_theme_constant_override("separation", 10)
        scroll.add_child(content)

    var movable_children: Array[Node] = []
    for child in arena.get_children():
        if child == navigation or child == scroll or child == self:
            continue
        movable_children.append(child)
    for child in movable_children:
        arena.remove_child(child)
        content.add_child(child)

    arena.move_child(navigation, 0)
    arena.move_child(scroll, 1)

func _disconnect_legacy_combat_result_handler() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var legacy_handler := Callable(scene, "_on_combat_finished")
    if CombatManager.combat_finished.is_connected(legacy_handler):
        CombatManager.combat_finished.disconnect(legacy_handler)

func _build_interface() -> void:
    event_card = RichTextLabel.new()
    event_card.name = "EventPreparation"
    event_card.bbcode_enabled = true
    event_card.custom_minimum_size = Vector2(0, 76)
    event_card.fit_content = true
    _insert_before_setup(event_card)

    var instruction_title := Label.new()
    instruction_title.name = "BattleInstructionsTitle"
    instruction_title.text = "INSTRUCCIONES PREVIAS"
    _insert_before_setup(instruction_title)

    var instruction_row := HBoxContainer.new()
    instruction_row.name = "BattleInstructions"
    _insert_before_setup(instruction_row)

    energy_selector = OptionButton.new()
    energy_selector.add_item("Energía equilibrada")
    energy_selector.add_item("Conservar energía")
    energy_selector.add_item("Gastar energía agresivamente")
    energy_selector.tooltip_text = "Define cuánto arriesga el gladiador al ejecutar su plan."
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
    loadout_summary.name = "LoadoutSummary"
    loadout_summary.bbcode_enabled = true
    loadout_summary.fit_content = true
    loadout_summary.custom_minimum_size = Vector2(0, 64)
    _insert_before_setup(loadout_summary)

    var tactical_title := Label.new()
    tactical_title.name = "TacticalPlanTitle"
    tactical_title.text = "PLAN TÁCTICO — PRIORIDAD DE USO"
    _insert_before_setup(tactical_title)

    var tactical_row := HBoxContainer.new()
    tactical_row.name = "TacticalPlanEditor"
    _insert_before_setup(tactical_row)

    ability_selector = OptionButton.new()
    ability_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tactical_row.add_child(ability_selector)

    condition_selector = OptionButton.new()
    condition_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for condition_id in TACTICAL_CONDITIONS.keys():
        condition_selector.add_item(str(TACTICAL_CONDITIONS[condition_id]))
        condition_selector.set_item_metadata(condition_selector.item_count - 1, condition_id)
    tactical_row.add_child(condition_selector)

    var add_button := Button.new()
    add_button.text = "Agregar orden"
    add_button.pressed.connect(_add_tactical_order)
    tactical_row.add_child(add_button)

    var remove_button := Button.new()
    remove_button.text = "Quitar última"
    remove_button.pressed.connect(_remove_last_order)
    tactical_row.add_child(remove_button)

    var reset_button := Button.new()
    reset_button.text = "Restablecer"
    reset_button.pressed.connect(_reset_tactical_plan)
    tactical_row.add_child(reset_button)

    tactical_plan_list = RichTextLabel.new()
    tactical_plan_list.name = "TacticalPlanList"
    tactical_plan_list.bbcode_enabled = true
    tactical_plan_list.custom_minimum_size = Vector2(0, 96)
    tactical_plan_list.fit_content = true
    _insert_before_setup(tactical_plan_list)

    var arena_setup := _node("Setup") as HBoxContainer
    if arena_setup != null:
        var gladiator_selector := arena_setup.get_node_or_null("GladiatorSelector") as OptionButton
        if gladiator_selector != null and not gladiator_selector.item_selected.is_connected(_on_gladiator_selected):
            gladiator_selector.item_selected.connect(_on_gladiator_selected)
        var start_button := arena_setup.get_node_or_null("StartDuel") as Button
        if start_button != null:
            start_button.text = "Confirmar plan y combatir"
            if not start_button.button_down.is_connected(_configure_battle):
                start_button.button_down.connect(_configure_battle)

    var playback_row := HBoxContainer.new()
    playback_row.name = "PlaybackControls"
    content.add_child(playback_row)

    var playback_label := Label.new()
    playback_label.text = "REPETICIÓN MANUAL"
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
    report.custom_minimum_size = Vector2(0, 150)
    report.scroll_active = true
    report.text = "[b]Informe[/b]\nTodavía no se disputó un combate."
    content.add_child(report)

    replay_timer = Timer.new()
    replay_timer.one_shot = true
    replay_timer.timeout.connect(_play_next_action)
    add_child(replay_timer)

func _insert_before_setup(control: Control) -> void:
    content.add_child(control)
    var setup := content.get_node_or_null("Setup")
    if setup != null:
        content.move_child(control, setup.get_index())

func _connect_signals() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    CombatManager.combat_failed.connect(_on_combat_failed)
    GameState.day_advanced.connect(func(_day: int): _refresh_event())
    EquipmentManager.equipment_changed.connect(func(_person_id: String): _refresh_tactical_editor())
    RosterManager.roster_changed.connect(_refresh_tactical_editor)
    GladiatorProgressionManager.progression_changed.connect(_refresh_tactical_editor)
    var tabs := arena.get_parent() as TabContainer
    if tabs != null and not tabs.tab_changed.is_connected(_on_tab_changed):
        tabs.tab_changed.connect(_on_tab_changed)

func _on_tab_changed(_index: int) -> void:
    var tabs := arena.get_parent() as TabContainer
    if tabs == null or tabs.current_tab < 0:
        return
    if tabs.get_tab_control(tabs.current_tab) != arena:
        _stop_replay()

func _on_gladiator_selected(_index: int) -> void:
    _refresh_tactical_editor()

func _selected_gladiator():
    var selector := _node("Setup/GladiatorSelector") as OptionButton
    if selector == null or selector.selected < 0:
        return null
    var selected_text := selector.get_item_text(selector.selected)
    for person in RosterManager.get_people():
        if person.role == "gladiator" and selected_text.begins_with(person.display_name):
            return person
    return null

func _refresh_tactical_editor() -> void:
    if ability_selector == null:
        return
    var fighter = _selected_gladiator()
    ability_selector.clear()
    if fighter == null:
        draft_plan.clear()
        loadout_summary.text = "[b]Preparación[/b]\nSeleccioná un gladiador para configurar el plan táctico."
        _refresh_tactical_plan_list()
        return

    var record := GladiatorProgressionManager.get_record(fighter.id)
    var learned: Dictionary = record.get("abilities", {})
    for ability_id in GladiatorProgressionManager.get_available_ability_ids(fighter.id):
        var ability_level := int(learned.get(ability_id, 0))
        if ability_level <= 0:
            continue
        var data: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
        ability_selector.add_item("%s %s" % [data.get("name", ability_id), _roman_level(ability_level)])
        ability_selector.set_item_metadata(ability_selector.item_count - 1, ability_id)

    draft_plan.assign(GladiatorProgressionManager.get_tactical_plan(fighter.id))
    var valid_plan: Array[Dictionary] = []
    for order in draft_plan:
        var ability_id := str(order.get("ability_id", ""))
        if int(learned.get(ability_id, 0)) > 0:
            valid_plan.append(order.duplicate(true))
    draft_plan = valid_plan.slice(0, MAX_TACTICAL_ORDERS)

    var loadout := EquipmentManager.get_equipped_loadout(fighter)
    loadout_summary.text = "[b]%s — Nivel %d — %s[/b]\nArma: %s | Armadura: %s | Escudo: %s\nHabilidades aprendidas: %d | Órdenes preparadas: %d/%d" % [
        fighter.display_name,
        int(record.get("level", 1)),
        GladiatorProgressionManager.get_specialization_name(str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION))),
        loadout.get("weapon_name", "Ninguno"),
        loadout.get("armor_name", "Ninguna"),
        loadout.get("shield_name", "Ninguno"),
        learned.size(),
        draft_plan.size(),
        MAX_TACTICAL_ORDERS
    ]
    _refresh_tactical_plan_list()

func _add_tactical_order() -> void:
    if ability_selector.selected < 0 or draft_plan.size() >= MAX_TACTICAL_ORDERS:
        return
    var ability_id := str(ability_selector.get_item_metadata(ability_selector.selected))
    if ability_id.is_empty():
        return
    for existing in draft_plan:
        if str(existing.get("ability_id", "")) == ability_id:
            return
    var condition_id := "always"
    if condition_selector.selected >= 0:
        condition_id = str(condition_selector.get_item_metadata(condition_selector.selected))
    draft_plan.append({"ability_id":ability_id, "condition":condition_id})
    _refresh_tactical_plan_list()

func _remove_last_order() -> void:
    if not draft_plan.is_empty():
        draft_plan.pop_back()
    _refresh_tactical_plan_list()

func _reset_tactical_plan() -> void:
    draft_plan.clear()
    _refresh_tactical_plan_list()

func _refresh_tactical_plan_list() -> void:
    if tactical_plan_list == null:
        return
    var lines: Array[String] = ["[b]Prioridades tácticas — máximo %d[/b]" % MAX_TACTICAL_ORDERS]
    if draft_plan.is_empty():
        lines.append("Sin órdenes. El gladiador recurrirá al ataque básico de respaldo.")
    else:
        for index in range(draft_plan.size()):
            var order := draft_plan[index]
            var ability_id := str(order.get("ability_id", ""))
            var data: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
            var condition_id := str(order.get("condition", "always"))
            lines.append("%d. %s — %s" % [index + 1, data.get("name", ability_id), TACTICAL_CONDITIONS.get(condition_id, condition_id)])
    lines.append("[i]El orden superior tiene prioridad. Las órdenes imposibles se omiten y se evalúa la siguiente.[/i]")
    tactical_plan_list.text = "\n".join(lines)

func _configure_battle() -> void:
    var fighter = _selected_gladiator()
    if fighter == null:
        return
    GladiatorProgressionManager.set_tactical_plan(fighter.id, draft_plan)
    draft_plan.assign(GladiatorProgressionManager.get_tactical_plan(fighter.id))

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

    var prepared_abilities: Array[String] = []
    for order in draft_plan:
        prepared_abilities.append(str(order.get("ability_id", "")))
    CombatManager.configure_next_battle({
        "energy_rule":energy_rule,
        "surrender_threshold":surrender_threshold,
        "allow_finisher":finisher_toggle.button_pressed,
        "fighter_id":fighter.id,
        "tactical_plan":draft_plan.duplicate(true),
        "abilities":prepared_abilities,
        "techniques":["basic_attack"]
    })

func _roman_level(level: int) -> String:
    if level >= 3:
        return "III"
    if level == 2:
        return "II"
    return "I"

func _refresh_event() -> void:
    if event_card == null:
        return
    var data: Dictionary = CombatManager.get_current_event_details()
    event_card.text = "[b]%s[/b]\n%s\nRiesgo: %s | Recompensa: %s" % [data.get("name", "Arena"), data.get("rules", ""), data.get("risk", ""), data.get("reward", "")]

func _on_combat_finished(result: Dictionary) -> void:
    _stop_replay()
    last_result = result.duplicate(true)
    action_queue.assign(result.get("actions", []))
    var has_actions := not action_queue.is_empty()
    replay_button.disabled = not has_actions
    pause_button.disabled = true
    step_button.disabled = not has_actions
    skip_button.disabled = not has_actions
    _render_base_result(result)
    _render_report(result)
    call_deferred("_scroll_to_result")

func _render_base_result(result: Dictionary) -> void:
    var player_name := _node("Stage/PlayerCard/Name") as Label
    var enemy_name := _node("Stage/EnemyCard/Name") as Label
    if player_name != null:
        player_name.text = str(result.get("fighter", "Gladiador"))
    if enemy_name != null:
        enemy_name.text = str(result.get("enemy", "Rival"))
    _set_bar("Stage/PlayerCard/Health", int(result.get("player_health", 0)), int(result.get("player_max_health", 1)))
    _set_bar("Stage/PlayerCard/Energy", int(result.get("player_energy", 0)), int(result.get("player_max_energy", 1)))
    _set_bar("Stage/EnemyCard/Health", int(result.get("enemy_health", 0)), int(result.get("enemy_max_health", 1)))
    _set_bar("Stage/EnemyCard/Energy", int(result.get("enemy_energy", 0)), int(result.get("enemy_max_energy", 1)))

    var status := "VICTORIA" if bool(result.get("victory", false)) else ("RENDICIÓN" if bool(result.get("surrendered", false)) else "DERROTA")
    var result_label := _node("Result") as Label
    if result_label != null:
        result_label.text = "%s — %d denarios · Reputación %+d" % [status, int(result.get("reward", 0)), int(result.get("reputation", 0))]

    var combat_log := _node("CombatLog") as RichTextLabel
    if combat_log != null:
        combat_log.clear()
        combat_log.append_text("[b]Crónica de la arena[/b]\n")
        for entry: Variant in result.get("log", []):
            combat_log.append_text("%s\n" % str(entry))

    var scene := get_tree().current_scene
    if scene != null:
        var activity_log := scene.get_node_or_null("Margin/VBox/Tabs/Personal/Log") as RichTextLabel
        if activity_log != null:
            activity_log.append_text("\n[color=gold]%s terminó el combate semanal en %d rondas.[/color]" % [result.get("fighter", "El gladiador"), int(result.get("rounds", 0))])

func _on_combat_failed(reason: String) -> void:
    _stop_replay()
    var result_label := _node("Result") as Label
    if result_label != null:
        result_label.text = reason
    report.text = "[color=orange][b]No se pudo disputar el combate[/b][/color]\n%s" % reason
    _refresh_event()

func _start_replay() -> void:
    if action_queue.is_empty():
        return
    replay_timer.stop()
    replay_index = 0
    replay_paused = false
    pause_button.disabled = false
    pause_button.text = "Pausar"
    var combat_log := _node("CombatLog") as RichTextLabel
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
    pause_button.disabled = false
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

func _stop_replay() -> void:
    if replay_timer != null:
        replay_timer.stop()
    replay_paused = false
    replay_index = 0
    if pause_button != null:
        pause_button.text = "Pausar"
        pause_button.disabled = true

func _play_next_action() -> void:
    if replay_index >= action_queue.size():
        return
    var action: Dictionary = action_queue[replay_index]
    replay_index += 1
    _apply_snapshot(action)
    var combat_log := _node("CombatLog") as RichTextLabel
    if combat_log != null:
        combat_log.append_text("%s\n" % str(action.get("text", "")))
    var result_label := _node("Result") as Label
    if result_label != null:
        result_label.text = str(action.get("text", ""))
    if replay_index < action_queue.size() and not replay_paused:
        _schedule_next_action()
    elif replay_index >= action_queue.size():
        pause_button.disabled = true

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
    var player_body := _node("Stage/PlayerCard/Body") as ColorRect
    var enemy_body := _node("Stage/EnemyCard/Body") as ColorRect
    if player_body != null:
        player_body.modulate = Color(1.25, 1.25, 1.25) if str(action.get("actor", "")) == "player" else Color.WHITE
    if enemy_body != null:
        enemy_body.modulate = Color(1.25, 1.25, 1.25) if str(action.get("actor", "")) == "enemy" else Color.WHITE

func _set_bar(path: String, value: int, maximum: int) -> void:
    var bar := _node(path) as ProgressBar
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
    lines.append("[b]Uso de acciones[/b]")
    var stats: Dictionary = result.get("technique_stats", {})
    if stats.is_empty():
        lines.append("Sin datos de acciones.")
    else:
        for value in stats.values():
            var item: Dictionary = value
            lines.append("• %s: %d uso(s), %d daño" % [item.get("name", "Acción"), int(item.get("uses", 0)), int(item.get("damage", 0))])
    var status_stats: Dictionary = result.get("status_stats", {})
    if not status_stats.is_empty():
        lines.append("[b]Estados aplicados[/b]")
        for status_name in status_stats.keys():
            lines.append("• %s: %d" % [str(status_name).capitalize(), int(status_stats.get(status_name, 0))])
    report.text = "\n".join(lines)

func _scroll_to_result() -> void:
    await get_tree().process_frame
    if scroll == null or not is_instance_valid(scroll):
        return
    var bar := scroll.get_v_scroll_bar()
    scroll.scroll_vertical = int(bar.max_value)

func _node(relative_path: String) -> Node:
    if content == null or not is_instance_valid(content):
        return null
    return content.get_node_or_null(NodePath(relative_path))
