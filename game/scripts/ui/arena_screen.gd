extends VBoxContainer

const MAX_TACTICAL_ORDERS := 4
const FINAL_WEEK := 16

@onready var back_button: Button = $Header/Margin/Row/BackToFinca
@onready var event_header: Label = $Header/Margin/Row/WeekEvent
@onready var roster_list: ItemList = $Body/RosterPanel/Margin/Content/RosterList
@onready var fighter_info: RichTextLabel = $Body/RosterPanel/Margin/Content/FighterInfo
@onready var manage_button: Button = $Body/RosterPanel/Margin/Content/ManageGladiators
@onready var center_scroll: ScrollContainer = $Body/MainAndEncounter/CenterPanel/Margin/Scroll
@onready var event_conditions: RichTextLabel = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/EventConditions
@onready var player_name: Label = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ArenaVisual/Margin/VisualContent/Stage/PlayerCard/Name
@onready var player_health: ProgressBar = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ArenaVisual/Margin/VisualContent/Stage/PlayerCard/Health
@onready var player_energy: ProgressBar = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ArenaVisual/Margin/VisualContent/Stage/PlayerCard/Energy
@onready var enemy_name: Label = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ArenaVisual/Margin/VisualContent/Stage/EnemyCard/Name
@onready var enemy_health: ProgressBar = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ArenaVisual/Margin/VisualContent/Stage/EnemyCard/Health
@onready var enemy_energy: ProgressBar = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ArenaVisual/Margin/VisualContent/Stage/EnemyCard/Energy
@onready var selected_prep: RichTextLabel = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/Preparation/Margin/Content/SelectedPrep
@onready var tactic_selector: OptionButton = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/Preparation/Margin/Content/TacticRow/TacticSelector
@onready var energy_selector: OptionButton = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/Preparation/Margin/Content/TacticRow/EnergySelector
@onready var surrender_selector: OptionButton = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/Preparation/Margin/Content/RiskRow/SurrenderSelector
@onready var finisher_toggle: CheckButton = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/Preparation/Margin/Content/RiskRow/FinisherToggle
@onready var plan_summary: RichTextLabel = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/Preparation/Margin/Content/PlanSummary
@onready var edit_plan_button: Button = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ActionRow/EditPlan
@onready var equipment_button: Button = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ActionRow/Equipment
@onready var start_button: Button = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ActionRow/StartCombat
@onready var result_summary: RichTextLabel = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ResultSummary
@onready var replay_button: Button = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ReplayControls/Replay
@onready var pause_button: Button = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ReplayControls/Pause
@onready var step_button: Button = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ReplayControls/Step
@onready var skip_button: Button = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ReplayControls/Skip
@onready var speed_selector: OptionButton = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/ReplayControls/Speed
@onready var combat_log: RichTextLabel = $Body/MainAndEncounter/CenterPanel/Margin/Scroll/Content/CombatLog
@onready var opponent_info: RichTextLabel = $Body/MainAndEncounter/EncounterPanel/Margin/Scroll/Content/OpponentInfo
@onready var difficulty: RichTextLabel = $Body/MainAndEncounter/EncounterPanel/Margin/Scroll/Content/Difficulty
@onready var rewards: RichTextLabel = $Body/MainAndEncounter/EncounterPanel/Margin/Scroll/Content/Rewards
@onready var entry_info: RichTextLabel = $Body/MainAndEncounter/EncounterPanel/Margin/Scroll/Content/Entry
@onready var combat_conditions: RichTextLabel = $Body/MainAndEncounter/EncounterPanel/Margin/Scroll/Content/CombatConditions

var fighter_ids: Array[String] = []
var tactic_ids: Array[String] = []
var selected_fighter_id := ""
var action_queue: Array[Dictionary] = []
var replay_index := 0
var replay_paused := false
var replay_timer: Timer
var last_result: Dictionary = {}

func _ready() -> void:
    back_button.pressed.connect(_return_to_finca)
    manage_button.pressed.connect(_open_personal)
    edit_plan_button.pressed.connect(_open_progression)
    equipment_button.pressed.connect(_open_equipment)
    roster_list.item_selected.connect(_on_fighter_selected)
    tactic_selector.item_selected.connect(func(_index: int): _refresh_preparation())
    start_button.pressed.connect(_start_combat)
    replay_button.pressed.connect(_start_replay)
    pause_button.pressed.connect(_toggle_pause)
    step_button.pressed.connect(_step_replay)
    skip_button.pressed.connect(_skip_replay)

    replay_timer = Timer.new()
    replay_timer.one_shot = true
    replay_timer.timeout.connect(_play_next_action)
    add_child(replay_timer)

    _populate_static_selectors()
    _connect_runtime_signals()
    _refresh_all()
    _restore_persistent_result()

func _connect_runtime_signals() -> void:
    CombatManager.combat_finished.connect(_on_combat_finished)
    CombatManager.combat_failed.connect(_on_combat_failed)
    RosterManager.roster_changed.connect(_refresh_roster)
    GameState.week_advanced.connect(func(_week: int): _on_week_changed())
    EquipmentManager.equipment_changed.connect(func(_person_id: String): _refresh_preparation())
    GladiatorProgressionManager.progression_changed.connect(_refresh_preparation)
    RivalManager.rivals_changed.connect(_refresh_encounter)
    GladiatorRivalryController.rivalry_changed.connect(func(_person_id: String, _opponent_id: String): _refresh_encounter())

func _populate_static_selectors() -> void:
    tactic_selector.clear()
    tactic_ids = CombatManager.get_tactic_ids()
    for tactic_id in tactic_ids:
        tactic_selector.add_item(CombatManager.get_tactic_name(tactic_id))
    var balanced_index := tactic_ids.find("balanced")
    tactic_selector.select(balanced_index if balanced_index >= 0 else 0)

    energy_selector.clear()
    energy_selector.add_item("Equilibrada")
    energy_selector.add_item("Conservar")
    energy_selector.add_item("Agresiva")

    surrender_selector.clear()
    surrender_selector.add_item("Bajo 10%")
    surrender_selector.add_item("Bajo 20%")
    surrender_selector.add_item("Bajo 30%")
    surrender_selector.add_item("Nunca")
    surrender_selector.select(1)

    speed_selector.clear()
    speed_selector.add_item("Velocidad x1")
    speed_selector.add_item("Velocidad x2")
    speed_selector.add_item("Velocidad x4")
    speed_selector.select(1)

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        _return_to_finca()
        get_viewport().set_input_as_handled()

func _return_to_finca() -> void:
    _stop_replay()
    FincaHubController.show_finca()

func _open_personal() -> void:
    _stop_replay()
    FincaHubController.open_system("personal")

func _open_progression() -> void:
    _stop_replay()
    FincaHubController.open_system("progresion")

func _open_equipment() -> void:
    _stop_replay()
    FincaHubController.open_system("equipamiento")

func _refresh_all() -> void:
    _refresh_event()
    _refresh_roster()
    _refresh_encounter()
    _refresh_preparation()

func _refresh_roster() -> void:
    var previous_id := selected_fighter_id
    roster_list.clear()
    fighter_ids.clear()

    for person in RosterManager.get_people():
        if str(person.role) != "gladiator":
            continue
        fighter_ids.append(str(person.id))
        var record: Dictionary = GladiatorProgressionManager.get_record(str(person.id))
        var state := "LISTO" if person.is_available_for_combat() else _fighter_state_text(person)
        roster_list.add_item("%s · Nv. %d\nSalud %d · Fatiga %d · %s" % [
            person.display_name,
            int(record.get("level", 1)),
            int(person.health),
            int(person.fatigue),
            state
        ])
        roster_list.set_item_metadata(roster_list.item_count - 1, person.id)

    if fighter_ids.is_empty():
        selected_fighter_id = ""
        fighter_info.text = "[b]Sin gladiadores disponibles[/b]\nComprá o entrená un gladiador para competir."
        start_button.disabled = true
        _clear_stage()
        _refresh_encounter()
        return

    var selected_index := fighter_ids.find(previous_id)
    if selected_index < 0:
        selected_index = 0
    selected_fighter_id = fighter_ids[selected_index]
    roster_list.select(selected_index)
    _refresh_fighter_details()
    _refresh_encounter()
    _refresh_preparation()

func _fighter_state_text(person) -> String:
    if int(person.injury_days) > 0:
        return "HERIDO"
    if int(person.fatigue) >= 85:
        return "AGOTADO"
    return "NO DISPONIBLE"

func _on_fighter_selected(index: int) -> void:
    if index < 0 or index >= fighter_ids.size():
        return
    selected_fighter_id = fighter_ids[index]
    _refresh_fighter_details()
    _refresh_encounter()
    _refresh_preparation()

func _selected_fighter():
    if selected_fighter_id.is_empty():
        return null
    return RosterManager.get_person(selected_fighter_id)

func _refresh_fighter_details() -> void:
    var fighter = _selected_fighter()
    if fighter == null:
        fighter_info.text = "Seleccioná un gladiador."
        _clear_stage()
        return

    var record: Dictionary = GladiatorProgressionManager.get_record(fighter.id)
    var specialization := GladiatorProgressionManager.get_specialization_name(str(record.get("specialization", GladiatorProgressionManager.DEFAULT_SPECIALIZATION)))
    fighter_info.text = "[b]%s[/b]\n%s · Nivel %d\nSalud %d · Fatiga %d · Moral %d\nATQ %d · DEF %d\nEstado: %s" % [
        fighter.display_name,
        specialization,
        int(record.get("level", 1)),
        int(fighter.health),
        int(fighter.fatigue),
        int(fighter.morale),
        int(fighter.get_base_attack()),
        int(fighter.get_base_defense()),
        "Listo" if fighter.is_available_for_combat() else _fighter_state_text(fighter).capitalize()
    ]
    player_name.text = fighter.display_name
    _set_bar(player_health, int(fighter.health), maxi(1, int(fighter.get_max_health())))
    _set_bar(player_energy, int(fighter.get_max_energy()), maxi(1, int(fighter.get_max_energy())))

func _clear_stage() -> void:
    player_name.text = "Tu gladiador"
    enemy_name.text = "Rival"
    _set_bar(player_health, 0, 100)
    _set_bar(player_energy, 0, 100)
    _set_bar(enemy_health, 0, 100)
    _set_bar(enemy_energy, 0, 100)

func _refresh_event() -> void:
    var event: Dictionary = CombatManager.get_current_event_details()
    event_header.text = "SEMANA %d · %s" % [GameState.get_week(), str(event.get("name", "Encuentro semanal"))]
    var finale_warning := ""
    if GameState.get_week() == FINAL_WEEK and not bool(CampaignManager.get_summary().get("final_combat_resolved", false)):
        finale_warning = "\n[color=orange][b]COMBATE FINAL DE LA DEMO[/b] · Este resultado decidirá la campaña.[/color]"
    event_conditions.text = "[b]%s[/b]\n%s\nRiesgo: %s · Recompensa: %s%s" % [
        event.get("name", "Arena"),
        event.get("rules", ""),
        event.get("risk", "—"),
        event.get("reward", "—"),
        finale_warning
    ]
    combat_conditions.text = "[b]CONDICIONES DEL COMBATE[/b]\n• %s\n• Riesgo: %s\n• Un gladiador por encuentro\n• Rendición según el plan elegido" % [
        event.get("rules", "Sin condiciones especiales."),
        event.get("risk", "—")
    ]
    rewards.text = "[b]RECOMPENSAS[/b]\n%s\nLa cifra exacta depende del rival y del resultado." % str(event.get("reward", "—"))
    entry_info.text = "[b]APUESTA / ENTRADA[/b]\nEntrada cubierta por el ludus.\nGanancia estimada: variable según dificultad."

func _refresh_encounter() -> void:
    var opponent: Dictionary = CombatManager.get_current_opponent_preview(selected_fighter_id)
    if not bool(opponent.get("known", false)):
        opponent_info.text = "[b]%s[/b]\n%s" % [
            opponent.get("title", "Oponente por confirmar"),
            opponent.get("description", "La organización todavía no anunció al rival.")
        ]
        difficulty.text = "[b]DIFICULTAD[/b]\nPor confirmar"
        enemy_name.text = str(opponent.get("title", "Rival"))
        _set_bar(enemy_health, 0, 100)
        _set_bar(enemy_energy, 0, 100)
        return

    var rivalry: Dictionary = opponent.get("rivalry", {})
    var rivalry_text := "Sin enfrentamientos previos"
    if not rivalry.is_empty():
        rivalry_text = "Marcador personal %d-%d · Intensidad %d%%" % [
            int(rivalry.get("wins", 0)),
            int(rivalry.get("losses", 0)),
            int(rivalry.get("intensity", 0))
        ]

    opponent_info.text = "[b]%s[/b]\n%s · Nivel %d\nCasa: %s\nRécord: %d victorias · %d derrotas\nFUE %d · AGI %d · RES %d · TEC %d\n%s" % [
        opponent.get("name", "Rival"),
        opponent.get("origin", "Desconocido"),
        int(opponent.get("level", 1)),
        opponent.get("rival_name", "Casa rival"),
        int(opponent.get("wins", 0)),
        int(opponent.get("losses", 0)),
        int(opponent.get("strength", 0)),
        int(opponent.get("agility", 0)),
        int(opponent.get("endurance", 0)),
        int(opponent.get("technique", 0)),
        rivalry_text
    ]
    enemy_name.text = str(opponent.get("name", "Rival"))
    var estimated_health := maxi(1, int(opponent.get("health", 100)))
    _set_bar(enemy_health, estimated_health, estimated_health)
    _set_bar(enemy_energy, 100, 100)
    difficulty.text = "[b]DIFICULTAD[/b]\n%s" % _difficulty_label(opponent)

func _difficulty_label(opponent: Dictionary) -> String:
    var fighter = _selected_fighter()
    if fighter == null:
        return "Sin gladiador seleccionado"
    var fighter_power := int(fighter.strength) + int(fighter.agility) + int(fighter.endurance) + int(fighter.technique)
    var opponent_power := int(opponent.get("strength", 0)) + int(opponent.get("agility", 0)) + int(opponent.get("endurance", 0)) + int(opponent.get("technique", 0)) + int(opponent.get("level", 1)) * 2
    var difference := opponent_power - fighter_power
    if difference >= 14:
        return "Extrema"
    if difference >= 6:
        return "Desafiante"
    if difference <= -10:
        return "Favorable"
    return "Equilibrada"

func _refresh_preparation() -> void:
    var fighter = _selected_fighter()
    if fighter == null:
        selected_prep.text = "[b]PREPARACIÓN[/b]\nSeleccioná un gladiador."
        plan_summary.text = "[b]PLAN TÁCTICO[/b]\nSin gladiador seleccionado."
        start_button.disabled = true
        return

    var record: Dictionary = GladiatorProgressionManager.get_record(fighter.id)
    var loadout: Dictionary = EquipmentManager.get_equipped_loadout(fighter)
    selected_prep.text = "[b]PREPARACIÓN DE %s[/b]\nSalud %d/%d · Fatiga %d · Moral %d\nArma: %s · Armadura: %s · Escudo: %s" % [
        fighter.display_name,
        int(fighter.health),
        int(fighter.get_max_health()),
        int(fighter.fatigue),
        int(fighter.morale),
        loadout.get("weapon_name", "Ninguna"),
        loadout.get("armor_name", "Ninguna"),
        loadout.get("shield_name", "Ninguno")
    ]

    var plan: Array = record.get("tactical_plan", [])
    var lines: Array[String] = ["[b]PLAN TÁCTICO[/b]"]
    if plan.is_empty():
        lines.append("Sin órdenes específicas · usará ataque básico.")
    else:
        for index in range(mini(plan.size(), MAX_TACTICAL_ORDERS)):
            var order: Dictionary = plan[index]
            var ability_id := str(order.get("ability_id", ""))
            var ability: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
            lines.append("%d. %s · %s" % [index + 1, ability.get("name", ability_id), str(order.get("condition", "always")).replace("_", " ").capitalize()])
    plan_summary.text = "\n".join(lines)
    start_button.disabled = not fighter.is_available_for_combat() or CombatManager.last_combat_day == GameState.day or CampaignManager.campaign_over
    if CombatManager.last_combat_day == GameState.day:
        start_button.text = "COMBATE SEMANAL COMPLETADO"
    elif CampaignManager.campaign_over:
        start_button.text = "CAMPAÑA FINALIZADA"
    elif not fighter.is_available_for_combat():
        start_button.text = "GLADIADOR NO DISPONIBLE"
    else:
        start_button.text = "ENTRAR A LA ARENA"

func _start_combat() -> void:
    var fighter = _selected_fighter()
    if fighter == null:
        _on_combat_failed("Seleccioná un gladiador para competir.")
        return
    if not fighter.is_available_for_combat():
        _on_combat_failed("El gladiador seleccionado no está disponible.")
        return

    var tactic_id := "balanced"
    if tactic_selector.selected >= 0 and tactic_selector.selected < tactic_ids.size():
        tactic_id = tactic_ids[tactic_selector.selected]

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

    var record: Dictionary = GladiatorProgressionManager.get_record(fighter.id)
    var plan: Array = record.get("tactical_plan", []).duplicate(true)
    var prepared_abilities: Array[String] = []
    for order_value in plan:
        if order_value is Dictionary:
            prepared_abilities.append(str((order_value as Dictionary).get("ability_id", "")))

    CombatManager.configure_next_battle({
        "fighter_id":fighter.id,
        "energy_rule":energy_rule,
        "surrender_threshold":surrender_threshold,
        "allow_finisher":finisher_toggle.button_pressed,
        "tactical_plan":plan,
        "abilities":prepared_abilities,
        "techniques":["basic_attack"]
    })

    start_button.disabled = true
    start_button.text = "COMBATE EN CURSO..."
    result_summary.text = "[b]El combate semanal está comenzando...[/b]"
    CombatManager.simulate_duel(fighter.id, tactic_id)

func _on_combat_finished(result: Dictionary) -> void:
    _stop_replay()
    last_result = result.duplicate(true)
    action_queue.clear()
    for action_value in result.get("actions", []):
        if action_value is Dictionary:
            action_queue.append((action_value as Dictionary).duplicate(true))
    replay_button.disabled = action_queue.is_empty()
    step_button.disabled = action_queue.is_empty()
    skip_button.disabled = action_queue.is_empty()
    _render_result(result)
    _append_activity_log("%s terminó el combate semanal en %d rondas." % [result.get("fighter", "El gladiador"), int(result.get("rounds", 0))])
    _refresh_roster()
    _refresh_event()
    call_deferred("_scroll_to_results")

func _on_combat_failed(reason: String) -> void:
    start_button.disabled = false
    result_summary.text = "[color=orange][b]No se pudo disputar el combate[/b][/color]\n%s" % reason
    _append_activity_log(reason, true)
    _refresh_preparation()
    call_deferred("_scroll_to_results")

func _render_result(result: Dictionary) -> void:
    var status := "VICTORIA" if bool(result.get("victory", false)) else ("RENDICIÓN" if bool(result.get("surrendered", false)) else "DERROTA")
    player_name.text = str(result.get("fighter", "Gladiador"))
    enemy_name.text = str(result.get("enemy", "Rival"))
    _set_bar(player_health, int(result.get("player_health", 0)), int(result.get("player_max_health", 1)))
    _set_bar(player_energy, int(result.get("player_energy", 0)), int(result.get("player_max_energy", 1)))
    _set_bar(enemy_health, int(result.get("enemy_health", 0)), int(result.get("enemy_max_health", 1)))
    _set_bar(enemy_energy, int(result.get("enemy_energy", 0)), int(result.get("enemy_max_energy", 1)))

    var injury := str(result.get("injury", ""))
    result_summary.text = "[b]%s · %s[/b]\n%s contra %s · %d rondas\nPremio: %d denarios · Reputación: %+d\nHerida: %s" % [
        result.get("event_name", "Arena"),
        status,
        result.get("fighter", "Gladiador"),
        result.get("enemy", "Rival"),
        int(result.get("rounds", 0)),
        int(result.get("reward", 0)),
        int(result.get("reputation", 0)),
        injury if not injury.is_empty() else "Ninguna"
    ]
    combat_log.clear()
    combat_log.append_text("[b]Crónica de la arena[/b]\n")
    for line in result.get("log", []):
        combat_log.append_text("%s\n" % str(line))
    if result.get("log", []).is_empty():
        for action_value in result.get("actions", []):
            if action_value is Dictionary:
                var text := str((action_value as Dictionary).get("text", ""))
                if not text.is_empty():
                    combat_log.append_text("%s\n" % text)

func _restore_persistent_result() -> void:
    if CombatManager.last_result.is_empty():
        return
    last_result = CombatManager.last_result.duplicate(true)
    _render_result(last_result)
    action_queue.clear()
    for action_value in last_result.get("actions", []):
        if action_value is Dictionary:
            action_queue.append((action_value as Dictionary).duplicate(true))
    replay_button.disabled = action_queue.is_empty()
    step_button.disabled = action_queue.is_empty()
    skip_button.disabled = action_queue.is_empty()

func _start_replay() -> void:
    if action_queue.is_empty():
        return
    replay_index = 0
    replay_paused = false
    pause_button.disabled = false
    pause_button.text = "Pausar"
    combat_log.clear()
    combat_log.append_text("[b]Repetición del combate[/b]\n")
    _play_next_action()

func _toggle_pause() -> void:
    replay_paused = not replay_paused
    replay_timer.stop()
    pause_button.text = "Continuar" if replay_paused else "Pausar"
    if not replay_paused and replay_index < action_queue.size():
        _schedule_next_action()

func _step_replay() -> void:
    if action_queue.is_empty():
        return
    replay_paused = true
    replay_timer.stop()
    pause_button.disabled = false
    pause_button.text = "Continuar"
    _play_next_action()

func _skip_replay() -> void:
    replay_timer.stop()
    replay_paused = true
    if last_result.is_empty():
        return
    replay_index = action_queue.size()
    _render_result(last_result)
    pause_button.disabled = true

func _stop_replay() -> void:
    if replay_timer != null:
        replay_timer.stop()
    replay_index = 0
    replay_paused = false
    if pause_button != null:
        pause_button.disabled = true
        pause_button.text = "Pausar"

func _play_next_action() -> void:
    if replay_index >= action_queue.size():
        pause_button.disabled = true
        if not last_result.is_empty():
            _render_result(last_result)
        return
    var action := action_queue[replay_index]
    replay_index += 1
    _set_bar(player_health, int(action.get("player_health", 0)), int(action.get("player_max_health", 1)))
    _set_bar(player_energy, int(action.get("player_energy", 0)), int(action.get("player_max_energy", 1)))
    _set_bar(enemy_health, int(action.get("enemy_health", 0)), int(action.get("enemy_max_health", 1)))
    _set_bar(enemy_energy, int(action.get("enemy_energy", 0)), int(action.get("enemy_max_energy", 1)))
    var action_text := str(action.get("text", ""))
    if not action_text.is_empty():
        combat_log.append_text("%s\n" % action_text)
    if replay_index < action_queue.size() and not replay_paused:
        _schedule_next_action()
    elif replay_index >= action_queue.size():
        pause_button.disabled = true
        if not last_result.is_empty():
            result_summary.text = "[b]Repetición completada[/b]\n" + result_summary.text

func _schedule_next_action() -> void:
    var delay := 0.75
    if speed_selector.selected == 1:
        delay = 0.36
    elif speed_selector.selected == 2:
        delay = 0.15
    replay_timer.start(delay)

func _set_bar(bar: ProgressBar, value: int, maximum: int) -> void:
    bar.max_value = maxi(1, maximum)
    bar.value = clampi(value, 0, maxi(1, maximum))
    bar.tooltip_text = "%d/%d" % [value, maximum]

func _scroll_to_results() -> void:
    await get_tree().process_frame
    if center_scroll == null or not is_instance_valid(center_scroll):
        return
    center_scroll.scroll_vertical = int(center_scroll.get_v_scroll_bar().max_value)

func _append_activity_log(message: String, warning := false) -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var log := scene.get_node_or_null("Margin/VBox/Tabs/Personal/Log") as RichTextLabel
    if log == null:
        return
    var color := "orange" if warning else "gold"
    log.append_text("\n[color=%s]%s[/color]" % [color, message])

func _on_week_changed() -> void:
    _stop_replay()
    last_result.clear()
    action_queue.clear()
    replay_button.disabled = true
    step_button.disabled = true
    skip_button.disabled = true
    result_summary.text = "Todavía no se disputó el combate semanal."
    combat_log.text = "[b]Crónica de la arena[/b]"
    _refresh_all()
