extends "res://scripts/ui/arena_screen.gd"

const CombatV1ArenaRuntimeMonthlyScript = preload(
	"res://scripts/ui/combat_v1_arena_runtime_monthly.gd"
)

var _non_gt_panel: VBoxContainer
var _non_gt_status: Label
var _non_gt_start_button: Button
var _open_tournaments_button: Button


func _ready() -> void:
	_arena_runtime = CombatV1ArenaRuntimeMonthlyScript.new()
	super._ready()
	_install_non_gt_controls()
	TournamentManager.calendar_changed.connect(_refresh_non_gt_controls)
	TournamentManager.contract_accepted.connect(
		func(_contract: Dictionary): _refresh_non_gt_controls()
	)
	TournamentManager.contract_cancelled.connect(
		func(_contract: Dictionary): _refresh_non_gt_controls()
	)
	_refresh_all()


func _install_non_gt_controls() -> void:
	if _non_gt_panel != null:
		return
	_non_gt_panel = VBoxContainer.new()
	_non_gt_panel.name = "MonthlyArenaSetup"
	_non_gt_status = Label.new()
	_non_gt_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_non_gt_start_button = Button.new()
	_non_gt_start_button.text = "INICIAR COMBATE MENSUAL"
	_open_tournaments_button = Button.new()
	_open_tournaments_button.text = "VER TORNEOS DEL MES"
	_non_gt_panel.add_child(_non_gt_status)
	_non_gt_panel.add_child(_non_gt_start_button)
	_non_gt_panel.add_child(_open_tournaments_button)
	preparation_content.add_child(_non_gt_panel)
	preparation_content.move_child(_non_gt_panel, 1)
	_non_gt_start_button.pressed.connect(_start_non_gt_contract)
	_open_tournaments_button.pressed.connect(func(): FincaHubController.open_system("torneos"))
	_refresh_non_gt_controls()


func _refresh_all() -> void:
	super._refresh_all()
	_refresh_non_gt_controls()
	if _series_setup_panel != null:
		var status := str(_session.get("status", ""))
		var monthly_finished := (
			str(_session.get("session_kind", "")) == "monthly_non_gt"
			and status == "encounter_finished"
		)
		_series_setup_panel.set_session_active(
			status == "combat_running" or (status == "encounter_finished" and not monthly_finished)
		)


func _refresh_non_gt_controls() -> void:
	if _non_gt_panel == null or not is_instance_valid(_non_gt_panel):
		return
	var contract := _current_non_gt_contract()
	var running_non_gt := (
		str(_session.get("status", "")) == "combat_running"
		and str(_session.get("session_kind", "")) == "monthly_non_gt"
	)
	if not contract.is_empty():
		var fighters := _contract_fighter_names(contract)
		_non_gt_status.text = (
			"Contrato mensual: %s · %s · %s"
			% [
				str(contract.get("name", "Arena")),
				str(contract.get("format", "1v1")),
				fighters,
			]
		)
		_non_gt_start_button.disabled = running_non_gt
		_non_gt_start_button.text = (
			"COMBATE MENSUAL EN CURSO" if running_non_gt else "INICIAR COMBATE MENSUAL"
		)
		return

	var non_gt_count := 0
	for raw_event in TournamentManager.get_month_schedule(GameState.get_month()):
		if not raw_event is Dictionary:
			continue
		if (
			str((raw_event as Dictionary).get("competition", ""))
			in ["underworld", "official_minor"]
		):
			non_gt_count += 1
	_non_gt_status.text = (
		"Hay %d oportunidad(es) no-GT este mes. Inscribí gladiadores desde Torneos." % non_gt_count
	)
	_non_gt_start_button.disabled = true
	_non_gt_start_button.text = "INSCRIPCIÓN REQUERIDA"


func _start_non_gt_contract() -> void:
	var contract := _current_non_gt_contract()
	if contract.is_empty():
		_render_error(
			_ui_rejected(
				"monthly_contract_required",
				["Aceptá primero un combate de Bajo Mundo o un torneo menor."],
			)
		)
		return
	var result: Dictionary = _arena_runtime.start_non_gt_contract(contract, "player")
	_accept_started_session(result)


func _accept_started_session(result: Dictionary) -> Dictionary:
	if str(result.get("session_kind", "")) != "monthly_non_gt":
		return super._accept_started_session(result)
	if str(result.get("status", "")) != "combat_running":
		_render_error(result)
		return result
	if not CombatV1SessionStore.set_non_gt_session(result):
		var persistence_error := _ui_rejected(
			"session_persistence_rejected",
			["La sesión mensual no superó el contrato de persistencia Save v14."],
		)
		_render_error(persistence_error)
		return persistence_error
	_session = result.duplicate(true)
	_last_snapshot.clear()
	_refresh_all()
	_show_preparation_view()
	return _session.duplicate(true)


func advance_exchange_with_ai_requests(ai_requests_by_actor: Dictionary) -> Dictionary:
	if str(_session.get("session_kind", "")) != "monthly_non_gt":
		return super.advance_exchange_with_ai_requests(ai_requests_by_actor)
	if str(_session.get("status", "")) != "combat_running":
		return _ui_rejected("no_active_session", ["No hay una sesión Combat V1 activa."])

	var intents_result := _build_monthly_player_intents()
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
	if not CombatV1SessionStore.set_non_gt_session(next):
		var persistence_error := _ui_rejected(
			"session_persistence_rejected",
			["El estado mensual no superó el contrato de persistencia Save v14."],
		)
		_render_error(persistence_error)
		return persistence_error

	_session = next.duplicate(true)
	_refresh_all()
	if str(_session.get("status", "")) == "encounter_finished":
		_render_encounter_finished()
		_show_result_view()
	return _session.duplicate(true)


func _build_monthly_player_intents() -> Dictionary:
	var option_id := _selected_action_id()
	var targets_by_actor: Dictionary = {}
	if _arena_runtime.option_requires_manual_target(_session, option_id):
		var target_id := _selected_target_id()
		if target_id.is_empty():
			return _ui_rejected(
				"target_required",
				["La opción seleccionada requiere un objetivo enemigo explícito."],
			)
		for actor_id in _arena_runtime.get_active_player_ids(_session):
			targets_by_actor[actor_id] = target_id
	return _arena_runtime.build_player_intents(_session, option_id, targets_by_actor)


func _refresh_event() -> void:
	var month := GameState.get_month()
	var schedule := TournamentManager.get_month_schedule(month)
	var names: Array[String] = []
	for raw_event in schedule:
		if not raw_event is Dictionary:
			continue
		var event := raw_event as Dictionary
		names.append("%s (%s)" % [str(event.get("name", "Arena")), str(event.get("format", ""))])
	event_header.text = "MES %d · ARENA" % month
	if names.is_empty():
		event_conditions.text = "[b]COMBAT V1[/b]\nNo hay combates programados este mes."
		return
	event_conditions.text = (
		"[b]CARTELERA MENSUAL[/b]\n%s\n" % " · ".join(names)
		+ "GT I conserva sus puntos propios; Bajo Mundo y torneos menores tienen recompensas separadas."
	)


func _refresh_encounter_panel() -> void:
	var contract := _current_non_gt_contract()
	if contract.is_empty() and str(_session.get("session_kind", "")) != "monthly_non_gt":
		super._refresh_encounter_panel()
		return
	var source := contract if not contract.is_empty() else _session
	opponent_info.text = (
		(
			"[b]COMBATE MENSUAL NO-GT[/b]\n%s · Formato %s\n"
			% [
				str(source.get("name", source.get("event_name", "Arena"))),
				str(source.get("format", "")),
			]
		)
		+ "El rival se toma del catálogo Combat V1 canónico de los Ludi rivales."
	)
	combat_conditions.text = (
		"[b]AUTORIDAD[/b]\nCombatSimulator resuelve daño, KO y ganador. "
		+ "TournamentManager resuelve premio/reputación sin sumar puntos GT I."
	)
	difficulty.text = "[b]DIFICULTAD[/b]\n%d" % int(source.get("difficulty", 1))
	if str(source.get("competition", "")) == "underworld":
		rewards.text = (
			"[b]PREMIO[/b]\n%d denarios por victoria." % int(source.get("reward_per_win", 60))
		)
	else:
		rewards.text = (
			"[b]PREMIO[/b]\nCampeón %d · Eliminado %d denarios."
			% [int(source.get("champion_reward", 0)), int(source.get("eliminated_reward", 0))]
		)
	entry_info.text = "[b]ENTRADA[/b]\nContrato mensual aceptado desde Torneos."


func _render_stage(snapshot: Dictionary) -> void:
	super._render_stage(snapshot)
	if str(_session.get("session_kind", "")) != "monthly_non_gt":
		return
	action_text.text = (
		"Intercambio Combat V1 · %s" % str(_session.get("event_name", "Arena mensual"))
	)
	selected_prep.text = (
		"[b]SESIÓN MENSUAL COMBAT V1[/b]\nMes %d · %s · %s\nRival: %s"
		% [
			int(snapshot.get("month", 0)),
			str(_session.get("event_name", "Arena")),
			str(snapshot.get("format", "")),
			str(_session.get("rival_ludus_name", "Ludus rival")),
		]
	)


func _clear_stage() -> void:
	super._clear_stage()
	var contract := _current_non_gt_contract()
	if not contract.is_empty():
		enemy_name.text = "Rival mensual canónico"
		action_text.text = "Contrato listo: %s" % str(contract.get("name", "Arena"))
	elif TournamentManager.get_month_schedule(GameState.get_month()).size() > 0:
		enemy_name.text = "Cartelera mensual disponible"
		action_text.text = "Elegí e inscribite en un combate desde Torneos"


func _refresh_combat_controls() -> void:
	super._refresh_combat_controls()
	if str(_session.get("session_kind", "")) != "monthly_non_gt":
		return
	if str(_session.get("status", "")) == "encounter_finished":
		start_button.text = "COMBATE MENSUAL FINALIZADO"


func _render_encounter_finished() -> void:
	if str(_session.get("session_kind", "")) != "monthly_non_gt":
		super._render_encounter_finished()
		return
	var tournament_result := _session.get("last_tournament_result", {}) as Dictionary
	var victory := int(_session.get("player_wins", 0)) > 0
	var reward := int(tournament_result.get("reward_paid", 0))
	result_summary.text = (
		"[b]COMBATE MENSUAL COMPLETADO[/b]\n%s · Recompensa: %d denarios"
		% ["Victoria" if victory else "Derrota", reward]
	)
	if bool(_session.get("continuation_available", false)):
		result_summary.text += "\nBajo Mundo: el contrato sigue activo para otro combate este mes."
	combat_log.text = (
		"[b]Autoridades[/b]\nCombatSimulator: resultado de combate\n"
		+ "TournamentManager: premio/reputación no-GT · 0 puntos GT I"
	)


func _restore_persisted_session() -> void:
	var persisted_gt1 := CombatV1SessionStore.get_gt1_session(GameState.get_month())
	if not persisted_gt1.is_empty():
		_session = persisted_gt1.duplicate(true)
		_last_snapshot.clear()
		result_summary.text = "Sesión GT I Combat V1 restaurada desde Save v14."
		return
	var persisted_non_gt := CombatV1SessionStore.get_non_gt_session(GameState.get_month())
	if not persisted_non_gt.is_empty():
		_session = persisted_non_gt.duplicate(true)
		_last_snapshot.clear()
		result_summary.text = "Sesión mensual Combat V1 restaurada desde Save v14."
		return
	_session.clear()
	_last_snapshot.clear()


func _on_month_changed() -> void:
	CombatV1SessionStore.clear_gt1_session()
	CombatV1SessionStore.clear_non_gt_session()
	_session.clear()
	_last_snapshot.clear()
	view_result_button.disabled = true
	result_summary.text = "No hay una sesión Combat V1 persistida para el nuevo mes."
	combat_log.text = "[b]Crónica Combat V1[/b]"
	_refresh_all()
	_show_preparation_view()


func get_ui_contract() -> Dictionary:
	var contract := super.get_ui_contract()
	contract["screen"] = "ArenaScreenMonthly"
	contract["monthly_non_gt_enabled"] = true
	contract["monthly_non_gt_competitions"] = ["underworld", "official_minor"]
	contract["monthly_non_gt_formats"] = ["1v1", "1v2", "2v2"]
	contract["monthly_non_gt_setup_source"] = "TournamentManager active contracts"
	contract["monthly_non_gt_opponent_source"] = "canonical rival Combat V1 snapshots"
	contract["monthly_non_gt_gt1_points_authority"] = false
	contract["save_version_change_required"] = false
	return contract


func _current_non_gt_contract() -> Dictionary:
	if not _selected_fighter_id.is_empty():
		var selected := TournamentManager.get_active_contract_for_fighter(_selected_fighter_id)
		if str(selected.get("competition", "")) in ["underworld", "official_minor"]:
			return selected
	for raw_contract in TournamentManager.get_active_contracts():
		if not raw_contract is Dictionary:
			continue
		var contract := raw_contract as Dictionary
		if int(contract.get("scheduled_month", 0)) != GameState.get_month():
			continue
		if str(contract.get("competition", "")) in ["underworld", "official_minor"]:
			return contract.duplicate(true)
	return {}


func _contract_fighter_names(contract: Dictionary) -> String:
	var names: Array[String] = []
	for raw_name in contract.get("fighter_names", []) as Array:
		var value := str(raw_name)
		if not value.is_empty():
			names.append(value)
	if names.is_empty():
		names.append(str(contract.get("fighter_name", "Gladiador")))
	return " + ".join(names)
