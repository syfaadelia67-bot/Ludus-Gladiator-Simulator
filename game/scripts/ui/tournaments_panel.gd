extends VBoxContainer

@onready var back_button: Button = $Navigation/BackToFinca
@onready var status: Label = $Navigation/Status
@onready var scroll: ScrollContainer = $Scroll
@onready var event_list: ItemList = $Scroll/Content/TournamentContent/EventList
@onready var details: RichTextLabel = $Scroll/Content/TournamentContent/Right/Details
@onready var fighter_selector: OptionButton = $Scroll/Content/TournamentContent/Right/FighterSelector
@onready var accept_button: Button = $Scroll/Content/TournamentContent/Right/Accept
@onready var contracts: ItemList = $Scroll/Content/TournamentContent/Right/Contracts
@onready var cancel_button: Button = $Scroll/Content/TournamentContent/Right/Cancel

var event_ids: Array[String] = []
var fighter_ids: Array[String] = []
var contract_ids: Array[String] = []
var selected_event_id := ""
var selected_contract_id := ""

func _ready() -> void:
    back_button.pressed.connect(_return_to_finca)
    event_list.item_selected.connect(_on_event_selected)
    contracts.item_selected.connect(_on_contract_selected)
    accept_button.pressed.connect(_on_accept)
    cancel_button.pressed.connect(_on_cancel)
    TournamentManager.calendar_changed.connect(_refresh_all)
    TournamentManager.contract_failed.connect(_on_failed)
    TournamentManager.contract_accepted.connect(_on_accepted)
    TournamentManager.contract_cancelled.connect(_on_cancelled)
    RosterManager.roster_changed.connect(_refresh_fighters)
    _refresh_all()

func _unhandled_key_input(event: InputEvent) -> void:
    if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
        _return_to_finca()
        get_viewport().set_input_as_handled()

func _return_to_finca() -> void:
    FincaHubController.show_finca()

func _refresh_all() -> void:
    _refresh_events()
    _refresh_fighters()
    _refresh_contracts()
    _refresh_details()

func _scheduled_week(entry: Dictionary) -> int:
    return int(entry.get("scheduled_week", entry.get("scheduled_day", 0)))

func _refresh_events() -> void:
    event_list.clear()
    event_ids.clear()
    for event in TournamentManager.get_available_events():
        if bool(event.get("accepted", false)):
            continue
        event_ids.append(str(event.get("id", "")))
        event_list.add_item("Semana %d — %s — %d denarios" % [_scheduled_week(event), event.get("name", "Evento"), int(event.get("entry_fee", 0))])
    if event_ids.is_empty():
        selected_event_id = ""
        return
    var index := event_ids.find(selected_event_id)
    if index < 0:
        index = 0
        selected_event_id = event_ids[0]
    event_list.select(index)

func _refresh_fighters() -> void:
    var previous_id := ""
    if fighter_selector.selected >= 0 and fighter_selector.selected < fighter_ids.size():
        previous_id = fighter_ids[fighter_selector.selected]
    fighter_selector.clear()
    fighter_ids.clear()
    for person in RosterManager.get_people():
        if person.role == "gladiator" and person.is_available_for_combat():
            fighter_ids.append(person.id)
            fighter_selector.add_item("%s — Moral %d — Fatiga %d" % [person.display_name, person.morale, person.fatigue])
    if not fighter_ids.is_empty():
        var selected_index := fighter_ids.find(previous_id)
        fighter_selector.select(selected_index if selected_index >= 0 else 0)
    accept_button.disabled = fighter_ids.is_empty() or selected_event_id.is_empty()

func _refresh_contracts() -> void:
    contracts.clear()
    contract_ids.clear()
    for contract in TournamentManager.get_active_contracts():
        contract_ids.append(str(contract.get("id", "")))
        contracts.add_item("Semana %d — %s — %s" % [_scheduled_week(contract), contract.get("name", "Combate"), contract.get("fighter_name", "Gladiador")])
    if contract_ids.is_empty():
        selected_contract_id = ""
        cancel_button.disabled = true
        return
    var selected_index := contract_ids.find(selected_contract_id)
    if selected_index < 0:
        selected_index = 0
        selected_contract_id = contract_ids[0]
    contracts.select(selected_index)
    cancel_button.disabled = false

func _refresh_details() -> void:
    var selected: Dictionary = {}
    for event in TournamentManager.get_available_events():
        if str(event.get("id", "")) == selected_event_id:
            selected = event
            break
    if selected.is_empty():
        details.text = "No hay eventos disponibles para aceptar."
        accept_button.disabled = true
        return
    details.text = "[b]%s[/b]\nSemana programada: %d\nDificultad: %d\nReputación requerida: %d\nInscripción: %d denarios\nPremio base: %d denarios\n\nCancelar durante la última semana duplica la penalización." % [selected.get("name", "Evento"), _scheduled_week(selected), int(selected.get("difficulty", 1)), int(selected.get("min_reputation", 0)), int(selected.get("entry_fee", 0)), int(selected.get("base_reward", 0))]
    accept_button.disabled = fighter_ids.is_empty()

func _on_event_selected(index: int) -> void:
    if index >= 0 and index < event_ids.size():
        selected_event_id = event_ids[index]
        _refresh_details()

func _on_contract_selected(index: int) -> void:
    if index >= 0 and index < contract_ids.size():
        selected_contract_id = contract_ids[index]
        cancel_button.disabled = false

func _on_accept() -> void:
    if fighter_selector.selected < 0 or fighter_selector.selected >= fighter_ids.size():
        status.text = "Seleccioná un gladiador disponible."
        return
    TournamentManager.accept_event(selected_event_id, fighter_ids[fighter_selector.selected])

func _on_cancel() -> void:
    if selected_contract_id.is_empty():
        status.text = "Seleccioná un combate programado."
        return
    TournamentManager.cancel_contract(selected_contract_id)

func _on_accepted(contract: Dictionary) -> void:
    status.text = "%s quedó inscripto en %s para la semana %d." % [contract.get("fighter_name", "El gladiador"), contract.get("name", "el evento"), _scheduled_week(contract)]
    call_deferred("_scroll_to_contracts")

func _on_cancelled(contract: Dictionary) -> void:
    status.text = "Contrato cancelado. Penalización: %d denarios." % int(contract.get("cancel_penalty", 0))
    call_deferred("_scroll_to_contracts")

func _on_failed(reason: String) -> void:
    status.text = reason

func _scroll_to_contracts() -> void:
    if scroll == null or not is_instance_valid(scroll):
        return
    await get_tree().process_frame
    scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
