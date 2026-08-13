extends Node

const ArenaLimboAIRequestProviderScript = preload(
	"res://scripts/combat/arena_limboai_request_provider.gd"
)
const CombatV1ArenaRuntimeMonthlyScript = preload(
	"res://scripts/ui/combat_v1_arena_runtime_monthly.gd"
)

const MAX_EXCHANGES_PER_COMBAT := 400


func run() -> void:
	DataRepository.load_all()
	_add_test_gladiator("qa_arena_1v1", "QA Arena 1v1")
	_add_test_gladiator("qa_arena_1v2", "QA Arena 1v2")
	_add_test_gladiator("qa_arena_2v2_a", "QA Arena 2v2 A")
	_add_test_gladiator("qa_arena_2v2_b", "QA Arena 2v2 B")

	_assert_playable_format("1v1", ["qa_arena_1v1"], 1, true)
	_assert_playable_format("1v2", ["qa_arena_1v2"], 2, false)
	_assert_playable_format("2v2", ["qa_arena_2v2_a", "qa_arena_2v2_b"], 2, false)
	print("Monthly Arena playable integration tests passed")


func _assert_playable_format(
	format_id: String,
	player_ids: Array[String],
	opponent_count: int,
	require_underworld: bool,
) -> void:
	var event := _prepare_real_event(format_id, require_underworld)
	assert(not event.is_empty(), "A real monthly event must exist for %s" % format_id)
	if event.is_empty():
		return

	var gt_points_before := int(TournamentManager.get_gt1_summary().get("player_points", 0))
	var event_id := str(event.get("id", ""))
	var accepted := false
	if int(event.get("team_size", 1)) > 1:
		accepted = TournamentManager.accept_event_team(event_id, player_ids)
	else:
		accepted = TournamentManager.accept_event(event_id, player_ids[0])
	assert(accepted, "Real monthly event must be accepted for %s" % format_id)
	if not accepted:
		return

	var contract: Dictionary = TournamentManager.get_active_contract_for_event(event_id)
	assert(not contract.is_empty(), "Accepted monthly event must create an active contract")
	assert(str(contract.get("format", "")) == format_id)
	assert(str(contract.get("competition", "")) != "grand_tournament")
	if contract.is_empty():
		return

	var runtime = CombatV1ArenaRuntimeMonthlyScript.new()
	var session: Dictionary = runtime.start_non_gt_contract(contract, "player")
	assert(
		str(session.get("status", "")) == "combat_running",
		(
			"%s must start a real monthly combat session: %s"
			% [format_id, str(session.get("errors", []))]
		)
	)
	if str(session.get("status", "")) != "combat_running":
		return
	assert(str(session.get("session_kind", "")) == "monthly_non_gt")
	assert((session.get("opponent_fighter_ids", []) as Array).size() == opponent_count)
	assert(not str(session.get("rival_ludus_id", "")).is_empty())

	var final_session := _resolve_combat_to_completion(runtime, session, format_id)
	assert(
		str(final_session.get("status", "")) == "encounter_finished",
		(
			"%s must reach encounter_finished instead of deadlocking: %s"
			% [format_id, str(final_session.get("errors", []))]
		)
	)
	if str(final_session.get("status", "")) != "encounter_finished":
		return

	var combat_result := final_session.get("last_combat_result", {}) as Dictionary
	var tournament_result := final_session.get("last_tournament_result", {}) as Dictionary
	assert(str(combat_result.get("status", "")) == "combat_finished")
	assert(not str(combat_result.get("winner_team_id", "")).is_empty())
	assert(not tournament_result.is_empty())
	assert(str(tournament_result.get("competition", "")) != "grand_tournament")
	assert(int(final_session.get("player_points", -1)) == 0)
	assert(
		int(TournamentManager.get_gt1_summary().get("player_points", 0)) == gt_points_before,
		"Non-GT Arena combat must never award Torneo de Marte points",
	)


func _resolve_combat_to_completion(
	runtime, initial_session: Dictionary, format_id: String
) -> Dictionary:
	var session := initial_session.duplicate(true)
	var ai_provider = ArenaLimboAIRequestProviderScript.new()
	var exchanges := 0
	while str(session.get("status", "")) == "combat_running":
		if exchanges >= MAX_EXCHANGES_PER_COMBAT:
			assert(false, "%s exceeded exchange limit and likely deadlocked" % format_id)
			return session

		var player_ids: Array[String] = runtime.get_active_player_ids(session)
		var enemy_ids: Array[String] = runtime.get_active_enemy_ids(session)
		assert(not player_ids.is_empty())
		assert(not enemy_ids.is_empty())
		if player_ids.is_empty() or enemy_ids.is_empty():
			return session

		var action_id := _choose_player_action(session, player_ids)
		var targets_by_actor: Dictionary = {}
		if action_id == "light":
			for actor_id in player_ids:
				targets_by_actor[actor_id] = enemy_ids[0]
		var player_intents: Dictionary = runtime.build_player_intents(
			session, action_id, targets_by_actor
		)
		assert(
			str(player_intents.get("status", "")) == "ready",
			"%s player intent %s must remain legal" % [format_id, action_id],
		)
		if str(player_intents.get("status", "")) != "ready":
			return player_intents

		var ai_requests: Dictionary = ai_provider.build_requests(session, self, self)
		assert(ai_requests.size() == enemy_ids.size())
		for actor_id in enemy_ids:
			assert(ai_requests.has(actor_id))

		var next: Dictionary = (
			runtime
			. advance_exchange(
				session,
				player_intents.get("player_intents_by_actor", {}) as Dictionary,
				ai_requests,
			)
		)
		assert(
			str(next.get("status", "")) != "rejected",
			(
				"%s exchange %d must resolve through LimboAI + CombatSimulator: %s"
				% [format_id, exchanges + 1, str(next.get("errors", []))]
			)
		)
		if str(next.get("status", "")) == "rejected":
			return next

		var providers := next.get("last_intent_providers", {}) as Dictionary
		for actor_id in enemy_ids:
			assert(str(providers.get(actor_id, "")) == "limboai")
		session = next.duplicate(true)
		exchanges += 1

	assert(exchanges > 1, "%s must exercise a real multi-exchange combat" % format_id)
	return session


func _choose_player_action(session: Dictionary, player_ids: Array[String]) -> String:
	var active_loop := session.get("active_loop", {}) as Dictionary
	var state := active_loop.get("state", {}) as Dictionary
	for raw_fighter in state.get("fighters", []) as Array:
		var fighter := raw_fighter as Dictionary
		if not player_ids.has(str(fighter.get("id", ""))):
			continue
		if float(fighter.get("stamina", 0.0)) < 3.0:
			return "recover"
	return "light"


func _prepare_real_event(format_id: String, require_underworld: bool) -> Dictionary:
	if require_underworld:
		GameState.day = 1
		TournamentManager.prepare_month(1, true)
		for raw_event in TournamentManager.get_month_schedule(1):
			var event := raw_event as Dictionary
			if (
				str(event.get("competition", "")) == "underworld"
				and str(event.get("format", "")) == format_id
			):
				return event.duplicate(true)
		return {}

	for month in range(1, 13):
		GameState.day = month
		TournamentManager.prepare_month(month, true)
		for raw_event in TournamentManager.get_month_schedule(month):
			var event := raw_event as Dictionary
			if (
				str(event.get("competition", "")) == "official_minor"
				and str(event.get("format", "")) == format_id
			):
				return event.duplicate(true)
	return {}


func _add_test_gladiator(person_id: String, display_name: String) -> void:
	if RosterManager.get_person(person_id) != null:
		return
	var person := (
		LudusPerson
		. new(
			{
				"id": person_id,
				"name": display_name,
				"role": "gladiator",
				"strength": 7,
				"agility": 7,
				"endurance": 7,
				"resistance": 6,
				"intelligence": 5,
				"technique": 7,
				"health": 58,
				"fatigue": 0,
			}
		)
	)
	assert(RosterManager.add_person(person))
