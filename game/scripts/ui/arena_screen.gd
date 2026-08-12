extends VBoxContainer

const CombatV1ArenaRuntimeScript = preload("res://scripts/ui/combat_v1_arena_runtime.gd")
const CombatStatAdapterScript = preload("res://scripts/core/combat_stat_adapter.gd")
const GT1SeriesSetupPanelScene = preload("res://scenes/GT1SeriesSetupPanel.tscn")

const ACTION_LABELS := {
	"light": "Ataque ligero",
	"heavy": "Ataque pesado",
	"block": "Bloqueo",
	"parry": "Parada",
	"dodge": "Esquiva",
	"reposition": "Reposicionarse",
}

var _arena_runtime = CombatV1ArenaRuntimeScript.new()
var _stat_adapter = CombatStatAdapterScript.new()
var _session: Dictionary = {}
var _last_snapshot: Dictionary = {}
var _fighter_ids: Array[String] = []
var _action_ids: Array[String] = []
var _option_contracts_by_id: Dictionary = {}
var _target_ids: Array[String] = []
var _selected_fighter_id := ""
var _ai_request_provider: Callable = Callable()
var _series_setup_panel = null

@onready var center_scroll: ScrollContainer = $Body/CenterPanel/Margin/Scroll
@onready var center_content: Control = center_scroll.get_node("Content")
@onready var roster_content: Control = $Body/RosterPanel/Margin/Scroll/Content
@onready var encounter_content: Control = $Body/EncounterPanel/Margin/Scroll/Content

@onready var back_button: Button = center_content.get_node("TopBar/BackToFinca")
@onready var event_header: Label = center_content.get_node("TopBar/WeekEvent")
@onready var event_conditions: RichTextLabel = center_content.get_node(
	"EventBanner/Margin/Row/EventConditions"
)
@onready var roster_count: Label = roster_content.get_node("Header/Count")
@onready var roster_list: ItemList = roster_content.get_node("RosterList")
@onready var fighter_info: RichTextLabel = roster_content.get_node("FighterInfo")
@onready var manage_button: Button = roster_content.get_node("ManageGladiators")

@onready var preparation_view: VBoxContainer = center_content.get_node("PreparationView")
@onready var arena_visual: Control = preparation_view.get_node("ArenaVisual/Margin/VisualContent")
@onready var battlefield: Control = arena_visual.get_node("Battlefield")
@onready var preparation_content: Control = preparation_view.get_node("Preparation/Margin/Content")
@onready var options_content: Control = preparation_content.get_node("Options")
@onready var action_row: Control = preparation_view.get_node("ActionRow")
@onready var result_view: VBoxContainer = center_content.get_node("ResultView")
@onready var result_header: Control = result_view.get_node("ResultHeader")
@onready var replay_controls: Control = result_view.get_node("ReplayControls")

@onready var player_name: Label = battlefield.get_node("PlayerName")
@onready var player_health: ProgressBar = battlefield.get_node("PlayerHealth")
@onready var player_stamina: ProgressBar = battlefield.get_node("PlayerEnergy")
@onready var enemy_name: Label = battlefield.get_node("EnemyName")
@onready var enemy_health: ProgressBar = battlefield.get_node("EnemyHealth")
@onready var enemy_stamina: ProgressBar = battlefield.get_node("EnemyEnergy")
@onready var action_text: Label = battlefield.get_node("ActionText")
@onready var selected_prep: RichTextLabel = preparation_content.get_node("SelectedPrep")
@onready var action_selector: OptionButton = options_content.get_node("TacticSelector")
@onready var target_selector: OptionButton = options_content.get_node("EnergySelector")
@onready var legacy_surrender_selector: OptionButton = options_content.get_node("SurrenderSelector")
@onready var legacy_finisher_toggle: CheckButton = options_content.get_node("FinisherToggle")
@onready var plan_summary: RichTextLabel = preparation_content.get_node("PlanSummary")
@onready var edit_plan_button: Button = action_row.get_node("EditPlan")
@onready var equipment_button: Button = action_row.get_node("Equipment")
@onready var start_button: Button = action_row.get_node("StartCombat")
@onready var view_result_button: Button = action_row.get_node("ViewResult")

@onready var back_to_preparation_button: Button = result_header.get_node("BackToPreparation")
@onready var result_summary: RichTextLabel = result_view.get_node("ResultSummary")
@onready var replay_button: Button = replay_controls.get_node("Replay")
@onready var pause_button: Button = replay_controls.get_node("Pause")
@onready var step_button: Button = replay_controls.get_node("Step")
@onready var skip_button: Button = replay_controls.get_node("Skip")
@onready var speed_selector: OptionButton = replay_controls.get_node("Speed")
@onready var combat_log: RichTextLabel = result_view.get_node("CombatLog")

@onready var opponent_info: RichTextLabel = encounter_content.get_node("OpponentInfo")
@onready var difficulty: RichTextLabel = encounter_content.get_node("DifficultyRow/Difficulty")
@onready var rewards: RichTextLabel = encounter_content.get_node("RewardsRow/Rewards")
@onready var entry_info: RichTextLabel = encounter_content.get_node("EntryRow/Entry")
@onready var conditions_row: Control = encounter_content.get_node("ConditionsRow")
@onready var combat_conditions: RichTextLabel = conditions_row.get_node("CombatConditions")


func _ready() -> void:
	_install_series_setup_panel()
	back_button.pressed.connect(_return_to_finca)
	manage_button.pressed.connect(_open_personal)
	equipment_button.pressed.connect(_open_equipment)
	view_result_button.pressed.connect(_show_result_view)
	back_to_preparation_button.pressed.connect(_show_preparation_view)
	roster_list.item_selected.connect(_on_fighter_selected)
	action_selector.item_selected.connect(func(_index: int): _refresh_combat_controls())
	target_selector.item_selected.connect(func(_index: int): _refresh_combat_controls())
	start_button.pressed.connect(_request_exchange)
	visibility_changed.connect(_on_visibility_changed)
	RosterManager.roster_changed.connect(_refresh_roster)
	EquipmentManager.equipment_changed.connect(func(_person_id: String): _refresh_all())
	GameState.month_advanced.connect(func(_month: int): _on_month_changed())
	SaveManager.load_completed.connect(func(_path: String): call_deferred("_on_save_loaded"))

	_configure_legacy_scene_controls()
	_populate_actions()
	_restore_persisted_session()
	_refresh_all()
	_show_preparation_view()


func begin_gt1_session(
	month: int, player_team_id: String, player_ids_by_bout: Array, opponent_fighters_by_bout: Array
) -> Dictionary:
	var result: Dictionary = (
		_arena_runtime
		. start_gt1_session(
			month,
			player_team_id,
			player_ids_by_bout,
			opponent_fighters_by_bout,
		)
	)
	return _accept_started_session(result)


func set_ai_request_provider(provider: Callable) -> void:
	_ai_request_provider = provider
	_refresh_combat_controls()


func advance_exchange_with_ai_requests(ai_requests_by_actor: Dictionary) -> Dictionary:
	if str(_session.get("status", "")) != "combat_running":
		return _ui_rejected("no_active_session", ["No hay una sesión Combat V1 activa."])

	var option_id := _selected_action_id()
	var targets_by_actor: Dictionary = {}
	if _arena_runtime.option_requires_manual_target(_session, option_id):
		var target_id := _selected_target_id()
		if target_id.is_empty():
			return _ui_rejected(
				"target_required",
				["La opción seleccionada requiere un objetivo enemigo explícito."]
			)
		for actor_id in _arena_runtime.get_active_player_ids(_session):
			targets_by_actor[actor_id] = target_id

	var intents_result: Dictionary = (
		_arena_runtime
		. build_player_intents(
			_session,
			option_id,
			targets_by_actor,
		)
	)
	if str(intents_result.get("status", "")) != "ready":
		_render_error(intents_result)
		return intents_result

	var next: Dictionary = (
		_arena_runtime
		. advance_exchange(
			_session,
			intents_result.get("player_intents_by_actor", {}) as Dictionary,
			ai_requests_by_actor,
		)
	)
	if str(next.get("status", "")) == "rejected":
		_render_error(next)
		return next
	if not CombatV1SessionStore.set_gt1_session(next):
		var persistence_error := _ui_rejected(
			"session_persistence_rejected",
			["El nuevo estado GT I no superó el contrato de persistencia Save v14."],
		)
		_render_error(persistence_error)
		return persistence_error

	_session = next.duplicate(true)
	_refresh_all()
	if str(_session.get("status", "")) == "encounter_finished":
		_render_encounter_finished()
		_show_result_view()
	return _session.duplicate(true)


func get_ui_contract() -> Dictionary:
	return {
		"status": "frozen",
		"screen": "ArenaScreen",
		"time_axis": "month",
		"display_stats": ["FUE", "AGI", "TEC", "RES", "PV", "Stamina"],
		"runtime_bridge": "combat_v1_arena_runtime",
		"series_setup_panel": "GT1SeriesSetupPanel",
		"rival_ludi_source": "DataRepository.rival_ludi",
		"rival_fighter_source": "DataRepository.rival_combat_v1_snapshots",
		"month_16_beast_source": "DataRepository.beasts",
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"session_store": "CombatV1SessionStore",
		"running_session_restored_after_load": true,
		"legacy_combat_authority_allowed": false,
		"legacy_energy_authority_allowed": false,
		"legacy_ability_plan_allowed": false,
		"canonical_rank_1_skills_enabled": true,
		"skill_option_source": "DataRepository.skill_mechanics_v1",
		"ally_skill_targeting": "automatic_single_active_ally",
		"opponent_selection_is_external": false,
		"explicit_series_selection_required": true,
		"generated_opponents_allowed": false,
		"ai_requests_are_external": true,
		"save_version_change_required": false,
	}


func _install_series_setup_panel() -> void:
	if _series_setup_panel != null:
		return
	_series_setup_panel = GT1SeriesSetupPanelScene.instantiate()
	preparation_content.add_child(_series_setup_panel)
	preparation_content.move_child(_series_setup_panel, 1)
	_series_setup_panel.session_started.connect(_on_series_setup_session_started)
	_series_setup_panel.setup_rejected.connect(_render_error)


func _on_series_setup_session_started(result: Dictionary) -> void:
	_accept_started_session(result)


func _accept_started_session(result: Dictionary) -> Dictionary:
	if str(result.get("status", "")) != "combat_running":
		_render_error(result)
		return result
	if not CombatV1SessionStore.set_gt1_session(result):
		var persistence_error := _ui_rejected(
			"session_persistence_rejected",
			["La sesión GT I no superó el contrato de persistencia Save v14."],
		)
		_render_error(persistence_error)
		return persistence_error
	_session = result.duplicate(true)
	_last_snapshot.clear()
	_refresh_all()
	_show_preparation_view()
	return _session.duplicate(true)


func _configure_legacy_scene_controls() -> void:
	legacy_surrender_selector.visible = false
	legacy_finisher_toggle.visible = false
	edit_plan_button.visible = false
	replay_button.disabled = true
	pause_button.disabled = true
	step_button.disabled = true
	skip_button.disabled = true
	speed_selector.disabled = true
	player_stamina.tooltip_text = "Stamina Combat V1"
	enemy_stamina.tooltip_text = "Stamina Combat V1"
	view_result_button.disabled = true


func _populate_actions() -> void:
	var previous_id := _selected_action_id()
	action_selector.clear()
	_action_ids.clear()
	_option_contracts_by_id.clear()
	var first_available_index := -1
	for raw_contract in _arena_runtime.get_player_option_contracts(_session):
		var contract := raw_contract as Dictionary
		var option_id := str(contract.get("id", ""))
		if option_id.is_empty():
			continue
		var label := str(ACTION_LABELS.get(option_id, contract.get("name", option_id)))
		if str(contract.get("option_type", "action")) == "skill":
			label += " · SKILL"
		_action_ids.append(option_id)
		_option_contracts_by_id[option_id] = contract.duplicate(true)
		action_selector.add_item(label)
		var item_index := action_selector.item_count - 1
		var available := bool(contract.get("available", true))
		action_selector.set_item_disabled(item_index, not available)
		if available and first_available_index < 0:
			first_available_index = item_index
	if _action_ids.is_empty():
		return
	var selected_index := _action_ids.find(previous_id)
	if selected_index < 0 or action_selector.is_item_disabled(selected_index):
		selected_index = maxi(0, first_available_index)
	action_selector.select(selected_index)


func _refresh_all() -> void:
	_refresh_event()
	_refresh_roster()
	_refresh_snapshot()
	_refresh_encounter_panel()
	_populate_actions()
	_refresh_combat_controls()
	if _series_setup_panel != null:
		_series_setup_panel.set_session_active(
			str(_session.get("status", "")) in ["combat_running", "encounter_finished"]
		)


func _refresh_event() -> void:
	var month := GameState.get_month()
	var encounter := TournamentManager.get_gt1_encounter(month)
	if encounter.is_empty():
		event_header.text = "MES %d · ARENA" % month
		event_conditions.text = (
			"[b]COMBAT V1[/b]\n"
			+ "Este mes no contiene un encuentro GT I congelado. "
			+ "En la demo, los meses fuera de XIII, XVI y XX son de gestión y no abren combates de Arena."
		)
		return
	event_header.text = "MES %d · %s" % [month, str(encounter.get("tournament_name", "GT I"))]
	event_conditions.text = (
		"[b]ENCUENTRO %d · %s[/b]\n%s\nSerie: %d combates · %d puntos por victoria"
		% [
			int(encounter.get("encounter", 0)),
			str(encounter.get("format", "")),
			str(encounter.get("description", "")),
			int(encounter.get("series_bouts", 3)),
			int(encounter.get("points_per_win", 3)),
		]
	)


func _refresh_roster() -> void:
	var previous_id := _selected_fighter_id
	roster_list.clear()
	_fighter_ids.clear()
	for person in RosterManager.get_people():
		if str(person.role) != "gladiator":
			continue
		_fighter_ids.append(str(person.id))
		var adapted := (
			_stat_adapter
			. from_legacy(
				{
					"strength": person.strength,
					"agility": person.agility,
					"technique": person.technique,
					"resistance": person.resistance,
					"health": person.health,
				}
			)
		)
		var stats := adapted.get("stats", {}) as Dictionary
		var state := "LISTO" if person.is_available_for_combat() else "NO DISPONIBLE"
		(
			roster_list
			. add_item(
				(
					"%s · %s\nFUE %d · AGI %d · TEC %d · RES %d · PV %d"
					% [
						person.display_name,
						state,
						int(stats.get("FUE", 0)),
						int(stats.get("AGI", 0)),
						int(stats.get("TEC", 0)),
						int(stats.get("RES", 0)),
						int(stats.get("PV", 0)),
					]
				)
			)
		)
		roster_list.set_item_metadata(roster_list.item_count - 1, person.id)

	roster_count.text = "%d" % _fighter_ids.size()
	if _fighter_ids.is_empty():
		_selected_fighter_id = ""
		fighter_info.text = "[b]SIN GLADIADORES[/b]\nNo hay un combatiente disponible para presentar."
		return
	var selected_index := _fighter_ids.find(previous_id)
	if selected_index < 0:
		selected_index = 0
	_selected_fighter_id = _fighter_ids[selected_index]
	roster_list.select(selected_index)
	_refresh_fighter_details()


func _on_fighter_selected(index: int) -> void:
	if index < 0 or index >= _fighter_ids.size():
		return
	_selected_fighter_id = _fighter_ids[index]
	_refresh_fighter_details()


func _refresh_fighter_details() -> void:
	var person = RosterManager.get_person(_selected_fighter_id)
	if person == null:
		fighter_info.text = "Seleccioná un gladiador."
		return
	fighter_info.text = (
		"[b]%s[/b]\nFUE %d · AGI %d · TEC %d · RES %d\nPV %d · Estado: %s"
		% [
			person.display_name,
			int(person.strength),
			int(person.agility),
			int(person.technique),
			int(person.resistance),
			int(person.health),
			"Listo" if person.is_available_for_combat() else "No disponible",
		]
	)


func _refresh_snapshot() -> void:
	if str(_session.get("status", "")) not in ["combat_running", "encounter_finished"]:
		_clear_stage()
		return
	var snapshot: Dictionary = _arena_runtime.build_snapshot(_session)
	if str(snapshot.get("status", "")) != "ready":
		_render_error(snapshot)
		return
	_last_snapshot = snapshot.duplicate(true)
	view_result_button.disabled = false
	_render_stage(snapshot)


func _render_stage(snapshot: Dictionary) -> void:
	var player_team_id := str(_session.get("player_team_id", ""))
	var player_fighters: Array[Dictionary] = []
	var enemy_fighters: Array[Dictionary] = []
	for raw_fighter in snapshot.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("team", "")) == player_team_id:
			player_fighters.append(fighter)
		else:
			enemy_fighters.append(fighter)

	if not player_fighters.is_empty():
		var player := player_fighters[0]
		player_name.text = _fighter_display_name(str(player.get("id", "")))
		_set_bar(
			player_health, int(player.get("current_pv", 0)), int(player.get("max_pv", 1)), "PV"
		)
		_set_bar(player_stamina, int(round(float(player.get("stamina", 0.0)))), 100, "Stamina")
	if not enemy_fighters.is_empty():
		var enemy := enemy_fighters[0]
		enemy_name.text = str(enemy.get("id", "Rival"))
		_set_bar(enemy_health, int(enemy.get("current_pv", 0)), int(enemy.get("max_pv", 1)), "PV")
		_set_bar(enemy_stamina, int(round(float(enemy.get("stamina", 0.0)))), 100, "Stamina")

	action_text.text = "Intercambio Combat V1 · Combate %d/3" % int(snapshot.get("bout_number", 1))
	selected_prep.text = (
		(
			"[b]SESIÓN COMBAT V1[/b]\nMes %d · Formato %s · Combate %d/3\n"
			+ "Victorias: %d · Puntos del encuentro: %d"
		)
		% [
			int(snapshot.get("month", 0)),
			str(snapshot.get("format", "")),
			int(snapshot.get("bout_number", 1)),
			int(snapshot.get("player_wins", 0)),
			int(snapshot.get("player_points", 0)),
		]
	)


func _clear_stage() -> void:
	player_name.text = "Tu equipo"
	enemy_name.text = "Configurá el rival GT I"
	action_text.text = "Armá la serie GT I con las fuentes canónicas"
	_set_bar(player_health, 0, 1, "PV")
	_set_bar(player_stamina, 0, 100, "Stamina")
	_set_bar(enemy_health, 0, 1, "PV")
	_set_bar(enemy_stamina, 0, 100, "Stamina")


func _refresh_encounter_panel() -> void:
	var encounter := TournamentManager.get_gt1_encounter(GameState.get_month())
	if encounter.is_empty():
		opponent_info.text = (
			"\n"
			. join(
				[
					"[b]SIN ENCUENTRO GT I ESTE MES[/b]",
					"No se genera un rival de forma automática.",
				]
			)
		)
		combat_conditions.text = (
			"[b]AUTORIDAD[/b]\n"
			+ "CombatSimulator resuelve combate; TournamentManager registra puntos."
		)
	else:
		opponent_info.text = (
			"[b]RIVAL GT I CANÓNICO[/b]\n"
			+ "Elegí un Ludus y los perfiles Combat V1 de cada combate en el armado de serie. "
			+ "Mes XVI también permite seleccionar Jabalí, León u Oso desde el catálogo canónico."
		)
		combat_conditions.text = (
			"[b]FORMATO %s[/b]\n%s"
			% [
				str(encounter.get("format", "")),
				str(encounter.get("description", "")),
			]
		)
	difficulty.text = "[b]DIFICULTAD[/b]\nNo calculada por la UI."
	rewards.text = (
		"\n"
		. join(
			[
				"[b]PUNTUACIÓN[/b]",
				"3 puntos por victoria GT I. Sin premios económicos inventados.",
			]
		)
	)
	entry_info.text = "[b]ENTRADA[/b]\nSin coste automático definido por esta pantalla."


func _refresh_combat_controls() -> void:
	_refresh_targets()
	var option_id := _selected_action_id()
	var option_contract := _option_contracts_by_id.get(option_id, {}) as Dictionary
	var target_required := _arena_runtime.option_requires_manual_target(_session, option_id)
	target_selector.visible = target_required
	var session_running := str(_session.get("status", "")) == "combat_running"
	var provider_ready := _ai_request_provider.is_valid()
	var option_ready := bool(option_contract.get("available", true)) and not option_id.is_empty()
	var target_ready := not target_required or not _selected_target_id().is_empty()
	start_button.disabled = (
		not session_running or not provider_ready or not option_ready or not target_ready
	)

	var option_name := str(ACTION_LABELS.get(option_id, option_contract.get("name", option_id)))
	var option_type := str(option_contract.get("option_type", "action"))
	var target_relationship := str(option_contract.get("target_relationship", "none"))
	var availability_note := ""
	if not option_ready:
		availability_note = (
			"\n[color=orange]%s[/color]"
			% str(option_contract.get("unavailable_reason", "Opción no disponible."))
		)
	plan_summary.text = (
		(
			"[b]%s COMBAT V1[/b]\n%s · Stamina %d\nObjetivo: %s%s\n"
			+ "CombatSimulator conserva daño, KO y ganador."
		)
		% [
			"SKILL RANK 1" if option_type == "skill" else "ACCIÓN",
			option_name,
			int(option_contract.get("stamina_cost", 0)),
			target_relationship,
			availability_note,
		]
	)

	if not session_running:
		start_button.text = "ESPERANDO SERIE GT I"
	elif not provider_ready:
		start_button.text = "ESPERANDO POLÍTICA LIMBOAI"
	elif not option_ready:
		start_button.text = "OPCIÓN NO DISPONIBLE"
	elif not target_ready:
		start_button.text = "SELECCIONÁ OBJETIVO"
	else:
		start_button.text = "RESOLVER INTERCAMBIO"


func _refresh_targets() -> void:
	var previous := _selected_target_id()
	target_selector.clear()
	_target_ids.clear()
	var option_id := _selected_action_id()
	if _arena_runtime.option_requires_manual_target(_session, option_id):
		_target_ids = _arena_runtime.get_active_enemy_ids(_session)
	for target_id in _target_ids:
		target_selector.add_item(target_id)
	if _target_ids.is_empty():
		return
	var index := _target_ids.find(previous)
	if index < 0:
		index = 0
	target_selector.select(index)


func _selected_action_id() -> String:
	if action_selector.selected < 0 or action_selector.selected >= _action_ids.size():
		return ""
	return _action_ids[action_selector.selected]


func _selected_target_id() -> String:
	if target_selector.selected < 0 or target_selector.selected >= _target_ids.size():
		return ""
	return _target_ids[target_selector.selected]


func _request_exchange() -> void:
	if not _ai_request_provider.is_valid():
		_render_error(
			_ui_rejected("ai_provider_missing", ["La política LimboAI no está conectada."])
		)
		return
	var request_value: Variant = _ai_request_provider.call(_session.duplicate(true))
	if not request_value is Dictionary:
		_render_error(
			_ui_rejected(
				"invalid_ai_requests",
				["La política LimboAI debe devolver un Dictionary de solicitudes."],
			)
		)
		return
	advance_exchange_with_ai_requests(request_value as Dictionary)


func _render_encounter_finished() -> void:
	var snapshot := _arena_runtime.build_snapshot(_session)
	if str(snapshot.get("status", "")) == "ready":
		_last_snapshot = snapshot.duplicate(true)
	result_summary.text = (
		"[b]ENCUENTRO GT I COMPLETADO[/b]\nVictorias: %d/3 · Puntos: %d"
		% [
			int(_session.get("player_wins", 0)),
			int(_session.get("player_points", 0)),
		]
	)
	combat_log.text = (
		"[b]Autoridades[/b]\nCombatSimulator: resultado de combate\n"
		+ "TournamentManager: puntuación y progreso GT I"
	)


func _render_error(result: Dictionary) -> void:
	var errors: Array[String] = []
	for raw_error in result.get("errors", []) as Array:
		errors.append(str(raw_error))
	if errors.is_empty():
		errors.append(str(result.get("reason", "Operación rechazada por contrato Combat V1")))
	var error_header := "[color=orange][b]COMBAT V1 RECHAZÓ LA OPERACIÓN[/b][/color]"
	result_summary.text = "%s\n%s" % [error_header, "\n".join(errors)]
	combat_log.text = (
		"\n"
		. join(
			[
				"[b]Sin mutación de combate[/b]",
				"La operación falló antes de resolver el intercambio.",
			]
		)
	)
	view_result_button.disabled = false
	_show_result_view()


func _fighter_display_name(fighter_id: String) -> String:
	var person = RosterManager.get_person(fighter_id)
	if person == null:
		return fighter_id
	return str(person.display_name)


func _set_bar(bar: ProgressBar, value: int, maximum: int, label: String) -> void:
	bar.max_value = maxi(1, maximum)
	bar.value = clampi(value, 0, maxi(1, maximum))
	bar.tooltip_text = "%s %d/%d" % [label, value, maximum]


func _show_preparation_view() -> void:
	preparation_view.visible = true
	preparation_view.mouse_filter = Control.MOUSE_FILTER_PASS
	result_view.visible = false
	result_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_scroll.scroll_vertical = 0


func _show_result_view() -> void:
	if view_result_button.disabled:
		return
	preparation_view.visible = false
	preparation_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_view.visible = true
	result_view.mouse_filter = Control.MOUSE_FILTER_PASS


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		if _session.is_empty():
			_restore_persisted_session()
		_refresh_all()


func _on_save_loaded() -> void:
	_restore_persisted_session()
	_refresh_all()
	_show_preparation_view()


func _restore_persisted_session() -> void:
	var persisted := CombatV1SessionStore.get_gt1_session(GameState.get_month())
	if persisted.is_empty():
		_session.clear()
		_last_snapshot.clear()
		return
	_session = persisted.duplicate(true)
	_last_snapshot.clear()
	result_summary.text = "Sesión Combat V1 restaurada desde Save v14."


func _on_month_changed() -> void:
	CombatV1SessionStore.clear_gt1_session()
	_session.clear()
	_last_snapshot.clear()
	view_result_button.disabled = true
	result_summary.text = "No hay una sesión Combat V1 persistida para el nuevo mes."
	combat_log.text = "[b]Crónica Combat V1[/b]"
	_refresh_all()
	_show_preparation_view()


func _return_to_finca() -> void:
	FincaHubController.show_finca()


func _open_personal() -> void:
	FincaHubController.open_system("personal")


func _open_equipment() -> void:
	FincaHubController.open_system("equipamiento")


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_return_to_finca()
		get_viewport().set_input_as_handled()


func _ui_rejected(reason: String, errors: Array) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
	}
