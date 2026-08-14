extends "res://scripts/ui/combat_v1_arena_runtime.gd"

const CombatIntentSourceCollectorScript = preload(
	"res://scripts/combat/combat_intent_source_collector.gd"
)
const CombatPresentationEventAdapterScript = preload(
	"res://scripts/combat/combat_presentation_event_adapter.gd"
)
const MonthlyArenaCombatRuntimeScript = preload(
	"res://scripts/combat/monthly_arena_combat_runtime.gd"
)

const MAX_AUTOBATTLE_EXCHANGES := 400

var _monthly_runtime = MonthlyArenaCombatRuntimeScript.new()
var _monthly_intent_collector = CombatIntentSourceCollectorScript.new()
var _presentation_event_adapter = CombatPresentationEventAdapterScript.new()


func start_non_gt_contract(contract: Dictionary, player_team_id: String = "player") -> Dictionary:
	return _monthly_runtime.start_contract(contract, player_team_id)


func advance_exchange(
	session: Dictionary, player_intents_by_actor: Dictionary, ai_requests_by_actor: Dictionary
) -> Dictionary:
	if str(session.get("session_kind", "")) != "monthly_non_gt":
		return super.advance_exchange(session, player_intents_by_actor, ai_requests_by_actor)

	var state := _active_state(session)
	if state.is_empty():
		return _rejected(
			"missing_active_combat_state",
			["La Arena mensual requiere un CombatState activo."],
		)
	DataRepository.load_all()
	_monthly_intent_collector.set_skill_mechanics(DataRepository.get_skill_mechanics_v1())
	var collected := (
		_monthly_intent_collector
		. collect(
			state,
			str(session.get("player_team_id", "")),
			player_intents_by_actor,
			ai_requests_by_actor,
		)
	)
	if str(collected.get("status", "")) != "ready":
		return _rejected(
			str(collected.get("reason", "monthly_intent_collection_failed")),
			collected.get("errors", []) as Array,
		)

	var next := _monthly_runtime.advance_exchange(session, collected.get("intents", []) as Array)
	if str(next.get("status", "")) == "rejected":
		return next
	next["last_intent_providers"] = (
		(collected.get("providers_by_actor", {}) as Dictionary).duplicate(true)
	)
	next["last_skill_activations"] = (
		(collected.get("skill_activations_by_actor", {}) as Dictionary).duplicate(true)
	)
	return next


func resolve_autobattle(session: Dictionary, request_provider: Callable) -> Dictionary:
	if not request_provider.is_valid():
		return _rejected(
			"ai_provider_missing",
			["La política LimboAI no está conectada al autobattle."],
		)
	var current := session.duplicate(true)
	var presentation_events: Array = (
		(current.get("presentation_events", []) as Array).duplicate(true)
	)
	var exchanges := 0
	while str(current.get("status", "")) == "combat_running":
		if exchanges >= MAX_AUTOBATTLE_EXCHANGES:
			return _rejected(
				"autobattle_exchange_limit",
				["El combate superó el límite interno de intercambios sin finalizar."],
			)
		var request_value: Variant = request_provider.call(current.duplicate(true))
		if request_value is not Dictionary:
			return _rejected(
				"invalid_ai_requests",
				["La política LimboAI debe devolver un Dictionary de solicitudes."],
			)
		var next := advance_exchange(current, {}, request_value as Dictionary)
		if str(next.get("status", "")) == "rejected":
			return next
		_append_presentation_events(presentation_events, next)
		next["presentation_events"] = presentation_events.duplicate(true)
		current = next.duplicate(true)
		exchanges += 1
	return current


func build_snapshot(session: Dictionary) -> Dictionary:
	if str(session.get("session_kind", "")) != "monthly_non_gt":
		return super.build_snapshot(session)
	var state := _active_state(session)
	if state.is_empty():
		var last_result := session.get("last_combat_result", {}) as Dictionary
		state = last_result.get("state", {}) as Dictionary
	if state.is_empty():
		return _rejected(
			"missing_monthly_presentation_state",
			["La sesión mensual no contiene un estado de combate para presentar."],
		)

	var fighters: Array[Dictionary] = []
	for raw_fighter in state.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		var stats := fighter.get("stats", {}) as Dictionary
		(
			fighters
			. append(
				{
					"id": str(fighter.get("id", "")),
					"team": str(fighter.get("team", "")),
					"current_pv": int(fighter.get("current_pv", stats.get("PV", 0))),
					"max_pv": int(stats.get("PV", 1)),
					"stamina": float(fighter.get("stamina", 0.0)),
				}
			)
		)
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"month": int(session.get("month", 0)),
		"format": str(session.get("format", "")),
		"bout_number": 1,
		"player_wins": int(session.get("player_wins", 0)),
		"player_points": 0,
		"fighters": fighters.duplicate(true),
		"event_id": str(session.get("event_id", "")),
		"event_name": str(session.get("event_name", "Combate mensual")),
		"competition": str(session.get("competition", "")),
		"rival_ludus_id": str(session.get("rival_ludus_id", "")),
		"rival_ludus_name": str(session.get("rival_ludus_name", "")),
		"tournament_result":
		(session.get("last_tournament_result", {}) as Dictionary).duplicate(true),
		"presentation_events": (session.get("presentation_events", []) as Array).duplicate(true),
	}


func get_contract() -> Dictionary:
	var contract := super.get_contract()
	contract["session_authority"] = "gt1_or_monthly_arena_combat_runtime"
	contract["monthly_non_gt_runtime"] = "monthly_arena_combat_runtime"
	contract["monthly_non_gt_competitions"] = ["underworld", "official_minor"]
	contract["monthly_non_gt_formats"] = ["1v1", "1v2", "2v2"]
	contract["monthly_non_gt_gt1_points_authority"] = false
	contract["generated_opponents_allowed"] = false
	contract["autobattle"] = "limboai_for_all_active_fighters_until_encounter_finished"
	contract["autobattle_exchange_limit"] = MAX_AUTOBATTLE_EXCHANGES
	contract["presentation_events"] = "derived_from_combat_simulator_exchange_results"
	contract["presentation_math_authority"] = false
	contract["manual_midfight_input_required"] = false
	contract["save_version_change_required"] = false
	return contract


func _append_presentation_events(events: Array, session: Dictionary) -> void:
	var combat_result := session.get("last_combat_result", {}) as Dictionary
	var exchange_result := combat_result.get("last_exchange_result", {}) as Dictionary
	if exchange_result.is_empty():
		return
	var exchange_index := int(combat_result.get("exchange_index", 0))
	for raw_event in _presentation_event_adapter.build_exchange_events(
		exchange_index, exchange_result
	):
		events.append((raw_event as Dictionary).duplicate(true))
