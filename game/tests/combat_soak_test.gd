extends Node

const ArenaLimboAIRequestProviderScript = preload(
	"res://scripts/combat/arena_limboai_request_provider.gd"
)
const ArenaScreenMonthlyScript = preload("res://scripts/ui/arena_screen_monthly.gd")
const CombatV1ArenaRuntimeMonthlyScript = preload(
	"res://scripts/ui/combat_v1_arena_runtime_monthly.gd"
)

const DEFAULT_COMBAT_COUNT := 30
const MAX_COMBAT_COUNT := 10000
const MAX_EXCHANGES := 400
const COMBAT_COUNT_ARGUMENT_PREFIX := "--combat-count="
const SEED_BASE_ARGUMENT_PREFIX := "--combat-seed-base="
const FORMATS := ["1v1", "1v2", "2v2"]
const TACTICAL_SKILLS := [
	"counterattack",
	"charge",
	"closed_guard",
	"demolisher",
	"feint",
	"provoke",
	"execution",
	"aid",
	"anchor",
	"disarm",
	"immobilization",
	"interception",
]
const TACTICAL_CONDITIONS := [
	"always",
	"opening",
	"target_vulnerable",
	"target_guarding",
	"target_low_energy",
	"self_low_health",
	"self_low_energy",
	"after_defense",
]


func run() -> void:
	DataRepository.load_all()
	var combat_count := _get_int_argument(
		COMBAT_COUNT_ARGUMENT_PREFIX, DEFAULT_COMBAT_COUNT, 3, MAX_COMBAT_COUNT
	)
	var seed_base := _get_int_argument(SEED_BASE_ARGUMENT_PREFIX, 61001, 1, 2147483000)
	var failures: Array[String] = []
	var completed := 0
	var totals_by_format := {"1v1": 0, "1v2": 0, "2v2": 0}
	var total_exchanges := 0
	var total_actions := 0
	var total_attacks := 0
	var total_skill_actions := 0
	var total_knockouts := 0

	print("COMBAT SOAK START: combats=%d · seed_base=%d" % [combat_count, seed_base])
	for combat_index in range(combat_count):
		var format_id := str(FORMATS[combat_index % FORMATS.size()])
		var combat_seed := seed_base + combat_index
		var result := _run_combat(combat_index, combat_seed, format_id)
		if (result.get("errors", []) as Array).is_empty():
			completed += 1
			totals_by_format[format_id] = int(totals_by_format.get(format_id, 0)) + 1
		else:
			for raw_error in result.get("errors", []) as Array:
				failures.append(
					(
						"combat=%d format=%s seed=%d · %s"
						% [combat_index + 1, format_id, combat_seed, str(raw_error)]
					)
				)
		total_exchanges += int(result.get("exchanges", 0))
		total_actions += int(result.get("actions", 0))
		total_attacks += int(result.get("attacks", 0))
		total_skill_actions += int(result.get("skill_actions", 0))
		total_knockouts += int(result.get("knockouts", 0))

	print(
		(
			(
				"COMBAT SOAK SUMMARY: completed=%d/%d · 1v1=%d · 1v2=%d · 2v2=%d · "
				+ "exchanges=%d · actions=%d · attacks=%d · skill_actions=%d · knockouts=%d · failures=%d"
			)
			% [
				completed,
				combat_count,
				int(totals_by_format["1v1"]),
				int(totals_by_format["1v2"]),
				int(totals_by_format["2v2"]),
				total_exchanges,
				total_actions,
				total_attacks,
				total_skill_actions,
				total_knockouts,
				failures.size(),
			]
		)
	)
	for failure in failures:
		push_error("COMBAT SOAK FAILURE: %s" % failure)
	assert(failures.is_empty(), "Combat soak detected %d failing combat(s)." % failures.size())
	assert(
		total_skill_actions > 0,
		"Combat soak must exercise at least one Tactical Plan skill action."
	)
	print("Combat V1 multi-format headless soak test: OK")


func _run_combat(combat_index: int, combat_seed: int, format_id: String) -> Dictionary:
	var errors: Array[String] = []
	seed(combat_seed)
	if not NewCampaignCoordinator.reset_campaign_state():
		errors.append("new campaign reset failed")
		return _result(errors)

	var player_ids := _prepare_player_team(combat_index, format_id)
	var contract := _prepare_contract(format_id, player_ids, errors)
	if contract.is_empty():
		return _result(errors)

	var runtime = CombatV1ArenaRuntimeMonthlyScript.new()
	var session: Dictionary = runtime.start_non_gt_contract(contract, "player")
	if str(session.get("status", "")) != "combat_running":
		errors.append("combat did not start: %s" % str(session.get("errors", [])))
		return _result(errors)

	var initial_state := _active_state(session)
	var initial_fighter_ids := _fighter_ids(initial_state)
	if initial_fighter_ids.size() != _expected_fighter_count(format_id):
		errors.append("unexpected initial fighter count %d" % initial_fighter_ids.size())
		return _result(errors)

	var ai_provider = ArenaLimboAIRequestProviderScript.new()
	var request_provider := Callable(ai_provider, "build_requests").bind(self, self)
	var final_session: Dictionary = runtime.resolve_autobattle(session, request_provider)
	if str(final_session.get("status", "")) != "encounter_finished":
		errors.append(
			(
				"autobattle failed to finish: %s · %s"
				% [str(final_session.get("reason", "")), str(final_session.get("errors", []))]
			)
		)
		return _result(errors)

	var combat_result := final_session.get("last_combat_result", {}) as Dictionary
	var exchanges := int(combat_result.get("exchange_index", 0))
	if str(combat_result.get("status", "")) != "combat_finished":
		errors.append("final combat result is not combat_finished")
	if exchanges <= 0 or exchanges > MAX_EXCHANGES:
		errors.append("exchange count outside safe bounds: %d" % exchanges)
	var winner_team_id := str(combat_result.get("winner_team_id", ""))
	if winner_team_id.is_empty():
		errors.append("combat finished without winner_team_id")

	var final_state := combat_result.get("state", {}) as Dictionary
	_validate_final_state(final_state, initial_fighter_ids, winner_team_id, errors)
	var event_stats := _validate_event_stream(
		final_session.get("presentation_events", []) as Array,
		initial_fighter_ids,
		exchanges,
		winner_team_id,
		errors,
	)
	var providers := final_session.get("last_intent_providers", {}) as Dictionary
	if providers.is_empty():
		errors.append("final exchange did not report LimboAI providers")
	for provider_name in providers.values():
		if str(provider_name) != "limboai":
			errors.append("non-LimboAI intent provider detected: %s" % str(provider_name))

	return {
		"errors": errors.duplicate(),
		"exchanges": exchanges,
		"actions": int(event_stats.get("actions", 0)),
		"attacks": int(event_stats.get("attacks", 0)),
		"skill_actions": int(event_stats.get("skill_actions", 0)),
		"knockouts": int(event_stats.get("knockouts", 0)),
	}


func _prepare_contract(
	format_id: String, player_ids: Array[String], errors: Array[String]
) -> Dictionary:
	var event := _prepare_real_event(format_id)
	if event.is_empty():
		errors.append("no canonical official_minor event found")
		return {}
	var event_id := str(event.get("id", ""))
	if not _accept_event(event, player_ids):
		errors.append("canonical Arena event could not be accepted")
		return {}

	var contract := TournamentManager.get_active_contract_for_fighter(player_ids[0])
	if contract.is_empty():
		errors.append("accepted event did not create an active contract")
	elif str(contract.get("id", "")) != event_id:
		errors.append("active contract does not match accepted event")
	elif str(contract.get("format", "")) != format_id:
		errors.append("contract format mismatch: %s" % str(contract.get("format", "")))
	elif str(contract.get("competition", "")) == "grand_tournament":
		errors.append("combat soak unexpectedly entered Grand Tournament authority")
	if not errors.is_empty():
		return {}
	return contract


func _prepare_player_team(combat_index: int, format_id: String) -> Array[String]:
	var required := 2 if format_id == "2v2" else 1
	var result: Array[String] = []
	for slot in range(required):
		var fighter_id := "qa_soak_%s_%d_%d" % [format_id, combat_index, slot]
		var stat_shift := (combat_index + slot) % 5
		var person := (
			LudusPerson
			. new(
				{
					"id": fighter_id,
					"name": "QA Combat Soak %d/%d" % [combat_index + 1, slot + 1],
					"role": "gladiator",
					"strength": 5 + stat_shift,
					"agility": 5 + ((stat_shift + 1) % 5),
					"endurance": 6 + ((stat_shift + 2) % 4),
					"resistance": 5 + ((stat_shift + 3) % 5),
					"intelligence": 5 + ((stat_shift + 4) % 4),
					"technique": 5 + ((stat_shift + 2) % 5),
					"health": 48 + stat_shift * 4,
					"fatigue": 0,
				}
			)
		)
		assert(RosterManager.add_person(person))
		GladiatorProgressionManager.set_tactical_plan(
			fighter_id, _build_tactical_plan(combat_index + slot)
		)
		result.append(fighter_id)
	return result


func _build_tactical_plan(variant: int) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for offset in range(4):
		var skill_index := (variant * 3 + offset) % TACTICAL_SKILLS.size()
		var condition_index := (variant + offset) % TACTICAL_CONDITIONS.size()
		(
			plan
			. append(
				{
					"ability_id": str(TACTICAL_SKILLS[skill_index]),
					"condition": str(TACTICAL_CONDITIONS[condition_index]),
				}
			)
		)
	return plan


func _prepare_real_event(format_id: String) -> Dictionary:
	for month in range(1, 13):
		GameState.day = month
		TournamentManager.prepare_month(month, true)
		for raw_event in TournamentManager.get_month_schedule(month):
			if not raw_event is Dictionary:
				continue
			var event := raw_event as Dictionary
			if (
				str(event.get("competition", "")) == "official_minor"
				and str(event.get("format", "")) == format_id
			):
				return event.duplicate(true)
	return {}


func _accept_event(event: Dictionary, player_ids: Array[String]) -> bool:
	var event_id := str(event.get("id", ""))
	if int(event.get("team_size", 1)) > 1:
		return TournamentManager.accept_event_team(event_id, player_ids)
	var arena_screen = ArenaScreenMonthlyScript.new()
	var accepted: bool = bool(arena_screen.accept_non_gt_event_for_fighter(event_id, player_ids[0]))
	arena_screen.free()
	return accepted


func _validate_final_state(
	state: Dictionary,
	initial_fighter_ids: Array[String],
	winner_team_id: String,
	errors: Array[String],
) -> void:
	var final_ids := _fighter_ids(state)
	if final_ids.size() != initial_fighter_ids.size():
		errors.append("final state changed fighter cardinality")
	for fighter_id in initial_fighter_ids:
		if not final_ids.has(fighter_id):
			errors.append("final state lost fighter %s" % fighter_id)
	var seen: Dictionary = {}
	var winner_has_active := false
	var losing_team_has_active := false
	for raw_fighter in state.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		var fighter_id := str(fighter.get("id", ""))
		if seen.has(fighter_id):
			errors.append("duplicate fighter id in final state: %s" % fighter_id)
		seen[fighter_id] = true
		var stats := fighter.get("stats", {}) as Dictionary
		var current_pv := int(fighter.get("current_pv", stats.get("PV", 0)))
		var max_pv := int(stats.get("PV", 0))
		var stamina := float(fighter.get("stamina", 0.0))
		if current_pv > max_pv:
			errors.append("fighter %s exceeded max PV" % fighter_id)
		if stamina < 0.0:
			errors.append("fighter %s has negative Stamina %.3f" % [fighter_id, stamina])
		if current_pv > 0:
			if str(fighter.get("team", "")) == winner_team_id:
				winner_has_active = true
			else:
				losing_team_has_active = true
	if not winner_has_active:
		errors.append("winner team has no active fighter in final state")
	if losing_team_has_active:
		errors.append("losing team still has an active fighter after combat_finished")


func _validate_event_stream(
	events: Array,
	fighter_ids: Array[String],
	exchanges: int,
	winner_team_id: String,
	errors: Array[String],
) -> Dictionary:
	var actions := 0
	var attacks := 0
	var skill_actions := 0
	var knockouts := 0
	var exchange_starts := 0
	var finish_events := 0
	var ko_seen: Dictionary = {}
	for raw_event in events:
		if not raw_event is Dictionary:
			errors.append("presentation stream contains a non-Dictionary event")
			continue
		var event := raw_event as Dictionary
		var exchange_index := int(event.get("exchange_index", 0))
		if exchange_index <= 0 or exchange_index > exchanges:
			errors.append("presentation event has invalid exchange_index %d" % exchange_index)
		match str(event.get("type", "")):
			"exchange_started":
				exchange_starts += 1
			"action_declared":
				actions += 1
				_validate_actor_target(event, fighter_ids, errors)
				if not str(event.get("skill_id", "")).is_empty():
					skill_actions += 1
			"attack_resolved":
				attacks += 1
				_validate_actor_target(event, fighter_ids, errors)
				var damage := int(event.get("damage", 0))
				if damage < 0:
					errors.append("negative damage in presentation event")
				if not bool(event.get("hit", false)) and damage != 0:
					errors.append("miss event reported non-zero damage")
			"stamina_spent", "stamina_recovered":
				var fighter_id := str(event.get("fighter_id", ""))
				if not fighter_ids.has(fighter_id):
					errors.append("stamina event references unknown fighter %s" % fighter_id)
				if float(event.get("stamina_after", 0.0)) < 0.0:
					errors.append("stamina event reported negative Stamina")
			"fighter_knocked_out":
				knockouts += 1
				var fighter_id := str(event.get("fighter_id", ""))
				if not fighter_ids.has(fighter_id):
					errors.append("KO event references unknown fighter %s" % fighter_id)
				if ko_seen.has(fighter_id):
					errors.append("fighter %s emitted duplicate KO events" % fighter_id)
				ko_seen[fighter_id] = true
			"combat_finished":
				finish_events += 1
				if str(event.get("winner_team_id", "")) != winner_team_id:
					errors.append("presentation winner disagrees with CombatSimulator result")
				if str(event.get("winner_team_id", "")) == str(event.get("loser_team_id", "")):
					errors.append("combat_finished presentation winner equals loser")
	if exchange_starts != exchanges:
		errors.append(
			(
				"presentation exchange count mismatch: events=%d result=%d"
				% [exchange_starts, exchanges]
			)
		)
	if actions <= 0:
		errors.append("combat produced no action_declared events")
	if attacks <= 0:
		errors.append("combat produced no attack_resolved events")
	if knockouts <= 0:
		errors.append("combat produced no fighter_knocked_out events")
	if finish_events != 1:
		errors.append("combat produced %d combat_finished events" % finish_events)
	if events.is_empty() or str((events[-1] as Dictionary).get("type", "")) != "combat_finished":
		errors.append("presentation stream does not terminate with combat_finished")
	return {
		"actions": actions,
		"attacks": attacks,
		"skill_actions": skill_actions,
		"knockouts": knockouts,
	}


func _validate_actor_target(
	event: Dictionary, fighter_ids: Array[String], errors: Array[String]
) -> void:
	var actor_id := str(event.get("actor_id", ""))
	var target_id := str(event.get("target_id", ""))
	if not fighter_ids.has(actor_id):
		errors.append("event references unknown actor %s" % actor_id)
	if not target_id.is_empty() and not fighter_ids.has(target_id):
		errors.append("event references unknown target %s" % target_id)


func _active_state(session: Dictionary) -> Dictionary:
	var active_loop := session.get("active_loop", {}) as Dictionary
	return active_loop.get("state", {}) as Dictionary


func _fighter_ids(state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_fighter in state.get("fighters", []) as Array:
		if raw_fighter is Dictionary:
			result.append(str((raw_fighter as Dictionary).get("id", "")))
	return result


func _expected_fighter_count(format_id: String) -> int:
	match format_id:
		"1v1":
			return 2
		"1v2":
			return 3
		"2v2":
			return 4
	return 0


func _result(errors: Array[String]) -> Dictionary:
	return {
		"errors": errors.duplicate(),
		"exchanges": 0,
		"actions": 0,
		"attacks": 0,
		"skill_actions": 0,
		"knockouts": 0,
	}


func _get_int_argument(prefix: String, fallback: int, minimum: int, maximum: int) -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return clampi(int(argument.trim_prefix(prefix)), minimum, maximum)
	return fallback
