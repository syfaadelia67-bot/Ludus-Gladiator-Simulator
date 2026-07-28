extends VBoxContainer

@onready var rival_list: ItemList = $Content/RivalList
@onready var rival_details: RichTextLabel = $Content/OperationPanel/RivalDetails
@onready var agent_selector: OptionButton = $Content/OperationPanel/AgentSelector
@onready var operation_selector: OptionButton = $Content/OperationPanel/OperationSelector
@onready var operation_details: RichTextLabel = $Content/OperationPanel/OperationDetails
@onready var execute_button: Button = $Content/OperationPanel/ExecuteOperation
@onready var result_log: RichTextLabel = $ResultLog
@onready var tension_label: Label = $Header/Tension

var selected_rival_id: String = ""
var rival_ids: Array[String] = []
var agent_ids: Array[String] = []
var operation_ids: Array[String] = []

func _ready() -> void:
    rival_list.item_selected.connect(_on_rival_selected)
    agent_selector.item_selected.connect(_on_selection_changed)
    operation_selector.item_selected.connect(_on_selection_changed)
    execute_button.pressed.connect(_on_execute_operation)
    RivalManager.rivals_changed.connect(_refresh_all)
    RivalManager.operation_completed.connect(_on_operation_completed)
    RivalManager.operation_failed.connect(_on_operation_failed)
    RivalManager.rival_event.connect(_on_rival_event)
    RosterManager.roster_changed.connect(_refresh_agents)
    GameState.resources_changed.connect(_refresh_operation_details)
    _populate_operations()
    _refresh_all()

func _populate_operations() -> void:
    operation_selector.clear()
    operation_ids = RivalManager.get_operation_ids()
    for operation_id in operation_ids:
        var data := RivalManager.get_operation(operation_id)
        operation_selector.add_item(str(data.get("name", operation_id)))
    if not operation_ids.is_empty():
        operation_selector.select(0)

func _refresh_all() -> void:
    _refresh_rivals()
    _refresh_agents()
    _refresh_tension()
    _refresh_operation_details()

func _refresh_rivals() -> void:
    var previous_id := selected_rival_id
    rival_list.clear()
    rival_ids.clear()
    var rivals := RivalManager.get_rivals()
    for rival in rivals:
        var rival_id := str(rival.get("id", ""))
        rival_ids.append(rival_id)
        rival_list.add_item("%s — Relación %d — Sospecha %d" % [
            rival.get("name", "Rival"),
            int(rival.get("relation", 0)),
            int(rival.get("suspicion", 0))
        ])
    if rival_ids.is_empty():
        selected_rival_id = ""
        rival_details.text = "No hay rivales activos."
        execute_button.disabled = true
        return
    var selected_index := rival_ids.find(previous_id)
    if selected_index < 0:
        selected_index = 0
    selected_rival_id = rival_ids[selected_index]
    rival_list.select(selected_index)
    _refresh_rival_details()

func _refresh_agents() -> void:
    var previous_id := ""
    if agent_selector.selected >= 0 and agent_selector.selected < agent_ids.size():
        previous_id = agent_ids[agent_selector.selected]
    agent_selector.clear()
    agent_ids.clear()
    for person in RosterManager.get_people():
        if person.job != "espionage" or person.injury_days > 0:
            continue
        agent_ids.append(person.id)
        agent_selector.add_item("%s — INT %d / AGI %d" % [person.display_name, person.intelligence, person.agility])
    if agent_ids.is_empty():
        agent_selector.add_item("Sin agentes disponibles")
        agent_selector.disabled = true
        execute_button.disabled = true
    else:
        agent_selector.disabled = false
        var selected_index := agent_ids.find(previous_id)
        agent_selector.select(selected_index if selected_index >= 0 else 0)
        execute_button.disabled = selected_rival_id.is_empty()
    _refresh_operation_details()

func _refresh_tension() -> void:
    tension_label.text = "Tensión regional: %d | Operaciones: %d | Detectadas: %d" % [
        RivalManager.hostility_heat,
        RivalManager.operations_completed,
        RivalManager.operations_detected
    ]

func _refresh_rival_details() -> void:
    var rival := RivalManager.get_rival(selected_rival_id)
    if rival.is_empty():
        rival_details.text = "Seleccioná un ludus rival."
        return
    var intel := int(rival.get("intel", 0))
    var hidden_text := "Desconocido"
    var security_text := hidden_text
    var wealth_text := hidden_text
    var power_text := hidden_text
    if intel >= 20:
        security_text = str(rival.get("security", 0))
    if intel >= 40:
        wealth_text = str(rival.get("wealth", 0))
    if intel >= 60:
        power_text = str(rival.get("gladiator_power", 0))
    rival_details.text = "[b]%s[/b]\nPropietario: %s | Estado: %s\nRelación: %d | Sospecha: %d | Inteligencia obtenida: %d/100\nPrestigio: %d | Seguridad: %s | Riqueza: %s | Poder gladiador: %s" % [
        rival.get("name", "Rival"),
        rival.get("owner", "Desconocido"),
        rival.get("status", "Activo"),
        int(rival.get("relation", 0)),
        int(rival.get("suspicion", 0)),
        intel,
        int(rival.get("prestige", 0)),
        security_text,
        wealth_text,
        power_text
    ]

func _refresh_operation_details() -> void:
    _refresh_rival_details()
    if operation_selector.selected < 0 or operation_selector.selected >= operation_ids.size():
        operation_details.text = "Seleccioná una operación."
        execute_button.disabled = true
        return
    var operation_id := operation_ids[operation_selector.selected]
    var data := RivalManager.get_operation(operation_id)
    var chance_text := "Asigná un agente para calcular probabilidades."
    if not agent_ids.is_empty() and agent_selector.selected >= 0 and agent_selector.selected < agent_ids.size():
        var agent = RosterManager.get_person(agent_ids[agent_selector.selected])
        var rival := RivalManager.get_rival(selected_rival_id)
        if agent != null and not rival.is_empty():
            var skill := agent.intelligence * 6 + agent.agility * 3 + agent.loyalty / 5
            if agent.traits.has("mentor"):
                skill += 6
            if agent.traits.has("freedom_seeker"):
                skill -= 5
            var defense := int(rival.get("security", 50)) + int(rival.get("suspicion", 0)) / 2
            var success_chance := clampi(45 + skill / 3 - defense / 2, 12, 92)
            var detection_chance := clampi(int(data.get("risk", 20)) + defense / 4 - agent.agility * 2, 5, 85)
            chance_text = "Éxito estimado: %d%% | Detección estimada: %d%%" % [success_chance, detection_chance]
    operation_details.text = "[b]%s[/b]\nCosto: %d inteligencia y %d denarios\nRiesgo base: %d%%\n%s\n\nRecursos actuales: %d inteligencia y %d denarios" % [
        data.get("name", operation_id),
        int(data.get("intel_cost", 0)),
        int(data.get("denarii_cost", 0)),
        int(data.get("risk", 0)),
        chance_text,
        RosterManager.intelligence_points,
        GameState.denarii
    ]
    execute_button.disabled = selected_rival_id.is_empty() or agent_ids.is_empty()

func _on_rival_selected(index: int) -> void:
    if index < 0 or index >= rival_ids.size():
        return
    selected_rival_id = rival_ids[index]
    _refresh_operation_details()

func _on_selection_changed(_index: int) -> void:
    _refresh_operation_details()

func _on_execute_operation() -> void:
    if selected_rival_id.is_empty() or agent_ids.is_empty():
        _on_operation_failed("Seleccioná un rival y asigná al menos un agente a Espionaje.")
        return
    if operation_selector.selected < 0 or operation_selector.selected >= operation_ids.size():
        _on_operation_failed("Seleccioná una operación.")
        return
    var agent_id := agent_ids[agent_selector.selected]
    var operation_id := operation_ids[operation_selector.selected]
    RivalManager.run_operation(selected_rival_id, operation_id, agent_id)

func _on_operation_completed(result: Dictionary) -> void:
    var outcome := "ÉXITO" if bool(result.get("success", false)) else "FRACASO"
    var detection := " — DESCUBIERTA" if bool(result.get("detected", false)) else " — NO DETECTADA"
    result_log.append_text("\n\n[b]%s%s[/b]\n%s ejecutó %s contra %s.\n%s" % [
        outcome,
        detection,
        result.get("agent_name", "El agente"),
        result.get("operation_name", "una operación"),
        result.get("rival_name", "el rival"),
        result.get("effect", "")
    ])
    _refresh_all()

func _on_operation_failed(reason: String) -> void:
    result_log.append_text("\n[color=orange]%s[/color]" % reason)

func _on_rival_event(event: Dictionary) -> void:
    result_log.append_text("\n[color=red]%s[/color]" % str(event.get("description", "Un rival actuó contra la finca.")))
    _refresh_all()
