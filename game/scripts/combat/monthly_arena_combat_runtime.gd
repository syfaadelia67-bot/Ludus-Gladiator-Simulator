extends RefCounted

const Combat1v1LoopScript = preload("res://scripts/combat/combat_1v1_loop.gd")
const Combat1v2LoopScript = preload("res://scripts/combat/combat_1v2_loop.gd")
const Combat2v2LoopScript = preload("res://scripts/combat/combat_2v2_loop.gd")
const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const CombatRosterFighterAdapterScript = preload(
	"res://scripts/combat/combat_roster_fighter_adapter.gd"
)
const RivalSnapshotProviderScript = preload(
	"res://scripts/combat/gt1_rival_combat_snapshot_provider.gd"
)

const NON_GT_COMPETITIONS := ["underworld", "official_minor"]

var _combat_contract = CombatContractScript.new()
var _fighter_adapter = CombatRosterFighterAdapterScript.new()
var _rival_provider = RivalSnapshotProviderScript.new()
var _loop_1v1 = Combat1v1LoopScript.new()
var _loop_1v2 = Combat1v2LoopScript.new()
var _loop_2v2 = Combat2v2LoopScript.new()


func start_contract(contract: Dictionary, player_team_id: String = "player") -> Dictionary:
	var errors := _validate_contract_start(contract, player_team_id)
	if not errors.is_empty():
		return _rejected("invalid_monthly_arena_contract", errors, contract)

	var player_ids := _contract_player_ids(contract)
	var opponent_count := _opponent_count_for_format(str(contract.get("format", "")))
	var opponent_team_id := "rival_monthly"
	var opponent_result := _select_canonical_opponents(contract, opponent_count, opponent_team_id)
	if str(opponent_result.get("status", "")) != "ready":
		return _rejected(
			"monthly_rival_selection_failed",
			opponent_result.get("errors", []) as Array,
			contract,
		)

	var fighters: Array = []
	for player_id in player_ids:
		var adapted := _build_player_fighter(player_id, player_team_id)
		if str(adapted.get("status", "")) != "ready":
			return _rejected(
				"monthly_player_snapshot_failed",
				adapted.get("errors", []) as Array,
				contract,
			)
		fighters.append((adapted.get("fighter", {}) as Dictionary).duplicate(true))
	for raw_opponent in opponent_result.get("fighters", []) as Array:
		fighters.append((raw_opponent as Dictionary).duplicate(true))

	var format_id := str(contract.get("format", ""))
	var state := {"format": format_id, "fighters": fighters}
	var state_errors: Array[String] = _combat_contract.validate_state(state)
	if not state_errors.is_empty():
		return _rejected("invalid_monthly_combat_state", state_errors, contract)

	var active_loop := _start_loop(state)
	if str(active_loop.get("status", "")) != "running":
		return _rejected(
			"monthly_combat_loop_start_failed",
			active_loop.get("errors", []) as Array,
			contract,
		)

	return {
		"status": "combat_running",
		"session_kind": "monthly_non_gt",
		"errors": [],
		"month": GameState.get_month(),
		"event_id": str(contract.get("id", "")),
		"event_name": str(contract.get("name", "Combate mensual")),
		"competition": str(contract.get("competition", "")),
		"format": format_id,
		"player_team_id": player_team_id,
		"player_ids": player_ids.duplicate(),
		"fighter_id": player_ids[0],
		"rival_ludus_id": str(opponent_result.get("rival_ludus_id", "")),
		"rival_ludus_name": str(opponent_result.get("rival_ludus_name", "Ludus rival")),
		"opponent_fighter_ids": (opponent_result.get("fighter_ids", []) as Array).duplicate(),
		"active_loop": active_loop.duplicate(true),
		"completed_bouts": 0,
		"player_wins": 0,
		"player_points": 0,
		"last_combat_result": {},
		"last_tournament_result": {},
		"continuation_available": false,
		"combat_state_source": "live_roster_and_equipment_snapshots",
		"opponent_source": "canonical_rival_combat_v1_snapshots",
	}


func advance_exchange(session: Dictionary, intents: Array) -> Dictionary:
	var errors := _validate_running_session(session)
	if not errors.is_empty():
		return _rejected("invalid_monthly_arena_session", errors, session)

	var active_loop := session.get("active_loop", {}) as Dictionary
	var format_id := str(session.get("format", ""))
	var combat_result: Dictionary
	match format_id:
		"1v1":
			combat_result = _loop_1v1.advance(active_loop, intents)
		"1v2":
			combat_result = _loop_1v2.advance(active_loop, intents)
		"2v2":
			combat_result = _loop_2v2.advance(active_loop, intents)
		_:
			return _rejected(
				"unsupported_monthly_arena_format",
				["El combate mensual requiere formato 1v1, 1v2 o 2v2."],
				session,
			)

	if str(combat_result.get("status", "")) == "rejected":
		return _rejected(
			str(combat_result.get("reason", "monthly_combat_advance_failed")),
			combat_result.get("errors", []) as Array,
			session,
		)

	var next := session.duplicate(true)
	next["active_loop"] = combat_result.duplicate(true)
	next["last_combat_result"] = combat_result.duplicate(true)
	if str(combat_result.get("status", "")) != "combat_finished":
		next["status"] = "combat_running"
		return next
	return _complete_combat(next, combat_result)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"period": "month",
		"competitions": NON_GT_COMPETITIONS.duplicate(),
		"formats": ["1v1", "1v2", "2v2"],
		"player_source": "live_roster_and_equipment_snapshots",
		"opponent_source": "canonical_rival_combat_v1_snapshots",
		"generated_opponents_allowed": false,
		"combat_authority": "combat_simulator",
		"reward_and_reputation_authority": "tournament_manager",
		"gt1_points_authority": false,
		"save_version_change_required": false,
	}


func _complete_combat(session: Dictionary, combat_result: Dictionary) -> Dictionary:
	var player_team_id := str(session.get("player_team_id", ""))
	var player_won := (
		str(combat_result.get("outcome", "")) == "team_win"
		and str(combat_result.get("winner_team_id", "")) == player_team_id
	)
	var tournament_result := TournamentManager.register_combat_result(
		str(session.get("fighter_id", "")), player_won
	)
	if tournament_result.is_empty():
		return _rejected(
			"monthly_result_registration_failed",
			["TournamentManager rechazó el resultado del combate mensual."],
			session,
		)

	var next := session.duplicate(true)
	next["status"] = "encounter_finished"
	next["active_loop"] = combat_result.duplicate(true)
	next["last_combat_result"] = combat_result.duplicate(true)
	next["last_tournament_result"] = tournament_result.duplicate(true)
	next["completed_bouts"] = 1
	next["player_wins"] = 1 if player_won else 0
	next["player_points"] = 0
	next["continuation_available"] = not (
		TournamentManager.get_active_contract_for_event(str(session.get("event_id", ""))).is_empty()
	)
	return next


func _build_player_fighter(player_id: String, player_team_id: String) -> Dictionary:
	var person = RosterManager.get_person(player_id)
	if person == null or str(person.role) != "gladiator":
		return _source_rejected(["No existe el gladiador seleccionado: %s" % player_id])
	if not person.is_available_for_combat():
		return _source_rejected(["El gladiador %s no está disponible para combatir." % player_id])
	var equipped_stats: Variant = EquipmentManager.get_combat_v1_equipped_stats(person)
	var skill_context: Variant = EquipmentManager.get_combat_v1_skill_context(person)
	if not equipped_stats is Dictionary or not skill_context is Dictionary:
		return _source_rejected(["El equipo Combat V1 del gladiador no pudo resolverse."])
	var equipment := (equipped_stats as Dictionary).duplicate(true)
	equipment["skill_context"] = (skill_context as Dictionary).duplicate(true)
	return _fighter_adapter.build_from_person(person, player_team_id, equipment)


func _select_canonical_opponents(
	contract: Dictionary, opponent_count: int, opponent_team_id: String
) -> Dictionary:
	DataRepository.load_all()
	var ludi_value: Variant = DataRepository.get_rival_ludi()
	if not ludi_value is Array or (ludi_value as Array).is_empty():
		return _source_rejected(["No hay Ludi rivales canónicos disponibles."])
	var ludi := ludi_value as Array
	var month := maxi(1, int(contract.get("scheduled_month", GameState.get_month())))
	var seed_offset := (
		month + int(contract.get("difficulty", 1)) + str(contract.get("id", "")).length()
	)
	var start_index := seed_offset % ludi.size()

	for offset in range(ludi.size()):
		var ludus := ludi[(start_index + offset) % ludi.size()] as Dictionary
		var ludus_id := str(ludus.get("id", ""))
		if ludus_id.is_empty():
			continue
		var entries := DataRepository.get_rival_combat_v1_snapshots_for_ludus(ludus_id)
		var fighter_ids: Array[String] = []
		for raw_entry in entries:
			if not raw_entry is Dictionary:
				continue
			var fighter_value: Variant = (raw_entry as Dictionary).get("fighter", {})
			if not fighter_value is Dictionary:
				continue
			var fighter_id := str((fighter_value as Dictionary).get("id", ""))
			if not fighter_id.is_empty():
				fighter_ids.append(fighter_id)
		fighter_ids.sort()
		if fighter_ids.size() < opponent_count:
			continue

		var selected_fighters: Array[Dictionary] = []
		var selected_ids: Array[String] = []
		var fighter_offset := seed_offset % fighter_ids.size()
		for index in range(opponent_count):
			var fighter_id := fighter_ids[(fighter_offset + index) % fighter_ids.size()]
			var result := _rival_provider.get_snapshot(ludus_id, fighter_id, opponent_team_id)
			if str(result.get("status", "")) != "ready":
				selected_fighters.clear()
				selected_ids.clear()
				break
			selected_fighters.append(
				(result.get("fighter_snapshot", {}) as Dictionary).duplicate(true)
			)
			selected_ids.append(fighter_id)
		if selected_fighters.size() == opponent_count:
			return {
				"status": "ready",
				"errors": [],
				"rival_ludus_id": ludus_id,
				"rival_ludus_name": str(ludus.get("name", ludus_id)),
				"fighter_ids": selected_ids.duplicate(),
				"fighters": selected_fighters.duplicate(true),
			}
	return _source_rejected(["Ningún Ludus rival tiene suficientes snapshots Combat V1 válidos."])


func _start_loop(state: Dictionary) -> Dictionary:
	match str(state.get("format", "")):
		"1v1":
			return _loop_1v1.start(state)
		"1v2":
			return _loop_1v2.start(state)
		"2v2":
			return _loop_2v2.start(state)
		_:
			return {"status": "rejected", "errors": ["Formato mensual no soportado."]}


func _validate_contract_start(contract: Dictionary, player_team_id: String) -> Array[String]:
	var errors: Array[String] = []
	var competition := str(contract.get("competition", ""))
	if not NON_GT_COMPETITIONS.has(competition):
		errors.append("El runtime mensual sólo acepta Bajo Mundo o torneos oficiales menores.")
	if player_team_id.is_empty():
		errors.append("El combate mensual requiere player_team_id.")
	if int(contract.get("scheduled_month", 0)) != GameState.get_month():
		errors.append("El contrato de Arena debe pertenecer al mes actual.")
	var format_id := str(contract.get("format", ""))
	if format_id not in ["1v1", "1v2", "2v2"]:
		errors.append("Formato mensual no soportado: %s" % format_id)
	var player_ids := _contract_player_ids(contract)
	var expected_players := 2 if format_id == "2v2" else 1
	if player_ids.size() != expected_players:
		errors.append(
			"El formato %s requiere %d gladiador(es) del jugador." % [format_id, expected_players]
		)
	return errors


func _validate_running_session(session: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(session.get("status", "")) != "combat_running":
		errors.append("La sesión mensual debe estar combat_running.")
	if str(session.get("session_kind", "")) != "monthly_non_gt":
		errors.append("La sesión no pertenece al runtime mensual no-GT.")
	var active_loop_value: Variant = session.get("active_loop", null)
	if not active_loop_value is Dictionary:
		errors.append("La sesión mensual requiere un loop activo.")
	else:
		var active_loop := active_loop_value as Dictionary
		if str(active_loop.get("status", "")) != "running":
			errors.append("El loop mensual debe estar running.")
		var state_value: Variant = active_loop.get("state", null)
		if state_value is Dictionary:
			errors.append_array(_combat_contract.validate_state(state_value as Dictionary))
		else:
			errors.append("El loop mensual requiere CombatState.")
	return errors


func _contract_player_ids(contract: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_id in contract.get("fighter_ids", []) as Array:
		var fighter_id := str(raw_id)
		if not fighter_id.is_empty() and not result.has(fighter_id):
			result.append(fighter_id)
	if result.is_empty():
		var primary_id := str(contract.get("fighter_id", ""))
		if not primary_id.is_empty():
			result.append(primary_id)
	return result


func _opponent_count_for_format(format_id: String) -> int:
	return 2 if format_id in ["1v2", "2v2"] else 1


func _source_rejected(errors: Array) -> Dictionary:
	return {
		"status": "rejected",
		"reason": "source_unavailable",
		"errors": errors.duplicate(),
	}


func _rejected(reason: String, errors: Array, source: Dictionary) -> Dictionary:
	return {
		"status": "rejected",
		"session_kind": "monthly_non_gt",
		"reason": reason,
		"errors": errors.duplicate(),
		"month": int(source.get("month", source.get("scheduled_month", GameState.get_month()))),
		"event_id": str(source.get("event_id", source.get("id", ""))),
		"competition": str(source.get("competition", "")),
		"player_team_id": str(source.get("player_team_id", "")),
		"active_loop": {},
	}
