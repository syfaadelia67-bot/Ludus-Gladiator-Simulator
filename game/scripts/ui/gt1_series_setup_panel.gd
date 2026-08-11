extends PanelContainer

signal session_started(session: Dictionary)
signal setup_rejected(result: Dictionary)

const GT1SeriesSetupRuntimeScript = preload("res://scripts/ui/gt1_series_setup_runtime.gd")
const PLAYER_TEAM_ID := "player_ludus"
const BEAST_TEAM_ID := "beast_team"
const GT1_MONTHS := [13, 16, 20]

var _runtime = GT1SeriesSetupRuntimeScript.new()
var _month := 0
var _catalog: Dictionary = {}
var _session_active := false
var _player_selectors: Array[OptionButton] = []
var _player_labels: Array[Label] = []
var _opponent_selectors: Array[OptionButton] = []
var _opponent_labels: Array[Label] = []

@onready var source_summary: RichTextLabel = $Margin/Content/SourceSummary
@onready var opponent_mode_label: Label = $Margin/Content/ModeRow/OpponentModeLabel
@onready var opponent_mode_selector: OptionButton = $Margin/Content/ModeRow/OpponentModeSelector
@onready var rival_ludus_label: Label = $Margin/Content/ModeRow/RivalLudusLabel
@onready var rival_ludus_selector: OptionButton = $Margin/Content/ModeRow/RivalLudusSelector
@onready var setup_summary: RichTextLabel = $Margin/Content/SetupSummary
@onready var begin_series_button: Button = $Margin/Content/BeginSeries


func _ready() -> void:
	_player_selectors = [
		$Margin/Content/PlayerGrid/Player1Selector,
		$Margin/Content/PlayerGrid/Player2Selector,
		$Margin/Content/PlayerGrid/Player3Selector,
		$Margin/Content/PlayerGrid/Player4Selector,
		$Margin/Content/PlayerGrid/Player5Selector,
		$Margin/Content/PlayerGrid/Player6Selector,
	]
	_player_labels = [
		$Margin/Content/PlayerGrid/Player1Label,
		$Margin/Content/PlayerGrid/Player2Label,
		$Margin/Content/PlayerGrid/Player3Label,
		$Margin/Content/PlayerGrid/Player4Label,
		$Margin/Content/PlayerGrid/Player5Label,
		$Margin/Content/PlayerGrid/Player6Label,
	]
	_opponent_selectors = [
		$Margin/Content/OpponentGrid/Opponent1Selector,
		$Margin/Content/OpponentGrid/Opponent2Selector,
		$Margin/Content/OpponentGrid/Opponent3Selector,
		$Margin/Content/OpponentGrid/Opponent4Selector,
		$Margin/Content/OpponentGrid/Opponent5Selector,
		$Margin/Content/OpponentGrid/Opponent6Selector,
	]
	_opponent_labels = [
		$Margin/Content/OpponentGrid/Opponent1Label,
		$Margin/Content/OpponentGrid/Opponent2Label,
		$Margin/Content/OpponentGrid/Opponent3Label,
		$Margin/Content/OpponentGrid/Opponent4Label,
		$Margin/Content/OpponentGrid/Opponent5Label,
		$Margin/Content/OpponentGrid/Opponent6Label,
	]
	opponent_mode_selector.item_selected.connect(func(_index: int): _on_source_changed())
	rival_ludus_selector.item_selected.connect(func(_index: int): _on_source_changed())
	begin_series_button.pressed.connect(_begin_series)
	for selector in _player_selectors:
		selector.item_selected.connect(func(_index: int): _refresh_summary())
	for selector in _opponent_selectors:
		selector.item_selected.connect(func(_index: int): _refresh_summary())
	RosterManager.roster_changed.connect(func(): refresh_for_month(GameState.get_month()))
	GameState.month_advanced.connect(func(month: int): refresh_for_month(month))
	refresh_for_month(GameState.get_month())


func refresh_for_month(month: int) -> void:
	_month = month
	_catalog.clear()
	_configure_visibility(0, 0)
	_populate_modes()
	_populate_rival_ludi([])
	_populate_players()
	if not GT1_MONTHS.has(month):
		source_summary.text = (
			"[b]SIN SERIE GT I[/b]\n"
			+ "El armado de serie solo está disponible en los meses XIII, XVI y XX."
		)
		setup_summary.text = "No hay un encuentro GT I para configurar este mes."
		begin_series_button.disabled = true
		return
	_catalog = _runtime.get_gt1_setup_catalog(month)
	if _catalog.get("status") != "ready":
		_show_catalog_error(_catalog)
		return
	_configure_visibility(
		int(_catalog.get("player_slots", 0)), int(_catalog.get("opponent_slots", 0))
	)
	_populate_modes()
	_populate_rival_ludi(_catalog.get("rivals", []) as Array)
	_populate_opponents()
	_update_slot_labels()
	source_summary.text = (
		"[b]FUENTES CANÓNICAS[/b]\n"
		+ "Rivales: DataRepository.rival_combat_v1_snapshots · "
		+ "Bestias XVI: DataRepository.beasts. Sin generación automática."
	)
	_refresh_summary()


func set_session_active(active: bool) -> void:
	_session_active = active
	_refresh_summary()


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"months": GT1_MONTHS.duplicate(),
		"setup_runtime": "gt1_series_setup_runtime",
		"player_source": "RosterManager",
		"rival_ludi_source": "DataRepository.rival_ludi",
		"rival_fighter_source": "DataRepository.rival_combat_v1_snapshots",
		"rival_provider": "gt1_rival_combat_snapshot_provider",
		"month_16_beast_source": "DataRepository.beasts",
		"month_16_beast_adapter": "combat_beast_fighter_adapter",
		"month_13_player_slots": 1,
		"month_13_opponent_slots": 3,
		"month_16_player_slots": 3,
		"month_16_opponent_slots": 3,
		"month_20_player_slots": 6,
		"month_20_opponent_slots": 6,
		"explicit_selection_required": true,
		"generated_opponents_allowed": false,
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"save_version_change_required": false,
	}


func _populate_modes() -> void:
	opponent_mode_selector.clear()
	opponent_mode_selector.add_item("Gladiadores")
	opponent_mode_selector.set_item_metadata(0, "human")
	if _month == 16:
		opponent_mode_selector.add_item("Bestias")
		opponent_mode_selector.set_item_metadata(1, "beast")
	opponent_mode_selector.select(0)
	opponent_mode_selector.visible = _month == 16
	opponent_mode_label.visible = _month == 16


func _populate_rival_ludi(rivals: Array) -> void:
	_reset_selector(rival_ludus_selector, "Seleccionar Ludus rival")
	for raw_rival in rivals:
		if not raw_rival is Dictionary:
			continue
		var rival := raw_rival as Dictionary
		var rival_id := str(rival.get("id", ""))
		if rival_id.is_empty():
			continue
		rival_ludus_selector.add_item(str(rival.get("name", rival_id)))
		rival_ludus_selector.set_item_metadata(rival_ludus_selector.item_count - 1, rival_id)


func _populate_players() -> void:
	for selector in _player_selectors:
		_reset_selector(selector, "Seleccionar gladiador")
	for person in RosterManager.get_people():
		if str(person.role) != "gladiator" or not person.is_available_for_combat():
			continue
		for selector in _player_selectors:
			selector.add_item(str(person.display_name))
			selector.set_item_metadata(selector.item_count - 1, str(person.id))


func _populate_opponents() -> void:
	var mode := _selected_metadata(opponent_mode_selector)
	var human_mode := mode != "beast"
	rival_ludus_label.visible = human_mode
	rival_ludus_selector.visible = human_mode
	for selector in _opponent_selectors:
		_reset_selector(selector, "Seleccionar rival")
	if mode == "beast":
		for raw_beast in _catalog.get("beasts", []) as Array:
			if not raw_beast is Dictionary:
				continue
			var beast := raw_beast as Dictionary
			for selector in _opponent_selectors:
				selector.add_item(str(beast.get("name", beast.get("id", "Bestia"))))
				selector.set_item_metadata(selector.item_count - 1, str(beast.get("id", "")))
		return
	var rival_id := _selected_metadata(rival_ludus_selector)
	if rival_id.is_empty():
		return
	for raw_rival in _catalog.get("rivals", []) as Array:
		if not raw_rival is Dictionary or str((raw_rival as Dictionary).get("id", "")) != rival_id:
			continue
		for raw_fighter in (raw_rival as Dictionary).get("fighters", []) as Array:
			if not raw_fighter is Dictionary:
				continue
			var fighter := raw_fighter as Dictionary
			var fighter_id := str(fighter.get("id", ""))
			for selector in _opponent_selectors:
				selector.add_item(fighter_id)
				selector.set_item_metadata(selector.item_count - 1, fighter_id)
		break


func _configure_visibility(player_slots: int, opponent_slots: int) -> void:
	for index in range(_player_selectors.size()):
		var visible := index < player_slots
		_player_selectors[index].visible = visible
		_player_labels[index].visible = visible
	for index in range(_opponent_selectors.size()):
		var visible := index < opponent_slots
		_opponent_selectors[index].visible = visible
		_opponent_labels[index].visible = visible


func _update_slot_labels() -> void:
	if _month == 13:
		_player_labels[0].text = "Tu gladiador · serie completa"
		for index in range(3):
			_opponent_labels[index].text = "Rival · combate %d" % [index + 1]
	elif _month == 16:
		for index in range(3):
			_player_labels[index].text = "Tu gladiador · combate %d" % [index + 1]
			_opponent_labels[index].text = "Oponente · combate %d" % [index + 1]
	elif _month == 20:
		for index in range(6):
			var bout := int(index / 2) + 1
			var slot := "A" if index % 2 == 0 else "B"
			_player_labels[index].text = "Tu pareja · combate %d · %s" % [bout, slot]
			_opponent_labels[index].text = "Pareja rival · combate %d · %s" % [bout, slot]


func _on_source_changed() -> void:
	_populate_opponents()
	_refresh_summary()


func _refresh_summary() -> void:
	if not GT1_MONTHS.has(_month) or _catalog.get("status") != "ready":
		begin_series_button.disabled = true
		return
	var player_slots := int(_catalog.get("player_slots", 0))
	var opponent_slots := int(_catalog.get("opponent_slots", 0))
	var selected_players := _selected_values(_player_selectors, player_slots)
	var selected_opponents := _selected_values(_opponent_selectors, opponent_slots)
	var mode := _selected_metadata(opponent_mode_selector)
	var source_ready := (
		mode == "beast" or not _selected_metadata(rival_ludus_selector).is_empty()
	)
	var complete := (
		selected_players.size() == player_slots
		and selected_opponents.size() == opponent_slots
		and source_ready
	)
	begin_series_button.disabled = _session_active or not complete
	if _session_active:
		setup_summary.text = (
			"[b]SERIE ACTIVA[/b]\nTerminá o abandoná la sesión actual antes de armar otra."
		)
		return
	setup_summary.text = (
		"[b]ARMADO EXPLÍCITO[/b]\nMes %d · %s · Selecciones: %d/%d propias, %d/%d rivales."
		% [
			_month,
			"Bestias" if mode == "beast" else "Gladiadores",
			selected_players.size(),
			player_slots,
			selected_opponents.size(),
			opponent_slots,
		]
	)


func _begin_series() -> void:
	var result := _build_session()
	if str(result.get("status", "")) == "combat_running":
		session_started.emit(result.duplicate(true))
		return
	setup_rejected.emit(result.duplicate(true))


func _build_session() -> Dictionary:
	var rival_ludus_id := _selected_metadata(rival_ludus_selector)
	if _month == 13:
		return (
			_runtime
			. start_month_13_session(
				_selected_metadata(_player_selectors[0]),
				PLAYER_TEAM_ID,
				rival_ludus_id,
				_selected_values(_opponent_selectors, 3),
			)
		)
	if _month == 16:
		var player_ids := _selected_values(_player_selectors, 3)
		if _selected_metadata(opponent_mode_selector) == "beast":
			return (
				_runtime
				. start_month_16_beast_session(
					player_ids,
					PLAYER_TEAM_ID,
					_selected_values(_opponent_selectors, 3),
					BEAST_TEAM_ID,
				)
			)
		return (
			_runtime
			. start_month_16_human_session(
				player_ids,
				PLAYER_TEAM_ID,
				rival_ludus_id,
				_selected_values(_opponent_selectors, 3),
			)
		)
	if _month == 20:
		return (
			_runtime
			. start_month_20_session(
				_pairs(_selected_values(_player_selectors, 6)),
				PLAYER_TEAM_ID,
				rival_ludus_id,
				_pairs(_selected_values(_opponent_selectors, 6)),
			)
		)
	return {
		"status": "rejected",
		"reason": "unsupported_gt1_month",
		"errors": ["No player-facing GT I setup exists for the current month"],
	}


func _selected_values(selectors: Array[OptionButton], count: int) -> Array:
	var result: Array = []
	for index in range(mini(count, selectors.size())):
		var value := _selected_metadata(selectors[index])
		if not value.is_empty():
			result.append(value)
	return result


func _selected_metadata(selector: OptionButton) -> String:
	if selector.selected < 0 or selector.selected >= selector.item_count:
		return ""
	return str(selector.get_item_metadata(selector.selected))


func _pairs(values: Array) -> Array:
	if values.size() != 6:
		return []
	return [
		[values[0], values[1]],
		[values[2], values[3]],
		[values[4], values[5]],
	]


func _reset_selector(selector: OptionButton, prompt: String) -> void:
	selector.clear()
	selector.add_item(prompt)
	selector.set_item_metadata(0, "")
	selector.select(0)


func _show_catalog_error(result: Dictionary) -> void:
	var errors: Array[String] = []
	for raw_error in result.get("errors", []) as Array:
		errors.append(str(raw_error))
	source_summary.text = "[b]SETUP GT I BLOQUEADO[/b]\n%s" % "\n".join(errors)
	setup_summary.text = "No se generaron selecciones de reemplazo."
	begin_series_button.disabled = true
