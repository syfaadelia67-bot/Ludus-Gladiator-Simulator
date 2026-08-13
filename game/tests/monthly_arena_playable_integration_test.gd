extends Node

const ArenaLimboAIRequestProviderScript = preload(
	"res://scripts/combat/arena_limboai_request_provider.gd"
)
const CombatV1ArenaRuntimeMonthlyScript = preload(
	"res://scripts/ui/combat_v1_arena_runtime_monthly.gd"
)


func run() -> void:
	DataRepository.load_all()
	GameState.day = 1
	_add_test_gladiator("qa_arena_alpha", "QA Arena Alpha")
	_add_test_gladiator("qa_arena_beta", "QA Arena Beta")

	_assert_playable_format("1v1", ["qa_arena_alpha"], 1)
	_assert_playable_format("1v2", ["qa_arena_alpha"], 2)
	_assert_playable_format("2v2", ["qa_arena_alpha", "qa_arena_beta"], 2)
	print("Monthly Arena playable integration tests passed")


func _assert_playable_format(format_id: String, player_ids: Array[String], opponent_count: int) -> void:
	var runtime = CombatV1ArenaRuntimeMonthlyScript.new()
	var contract := {
		"id": "qa_%s_month_1" % format_id,
		"name": "QA Arena %s" % format_id,
		"competition": "official_minor",
		"scheduled_month": 1,
		"format": format_id,
		"fighter_id": player_ids[0],
		"fighter_ids": player_ids.duplicate(),
		"difficulty": 1,
	}
	var session: Dictionary = runtime.start_non_gt_contract(contract, "player")
	assert(
		str(session.get("status", "")) == "combat_running",
		"%s must start a real monthly combat session: %s"
		% [format_id, str(session.get("errors", []))]
	)
	assert(str(session.get("session_kind", "")) == "monthly_non_gt")
	assert((session.get("opponent_fighter_ids", []) as Array).size() == opponent_count)
	assert(not str(session.get("rival_ludus_id", "")).is_empty())

	var enemy_ids: Array[String] = runtime.get_active_enemy_ids(session)
	var active_player_ids: Array[String] = runtime.get_active_player_ids(session)
	assert(enemy_ids.size() == opponent_count)
	assert(active_player_ids.size() == player_ids.size())

	var targets_by_actor: Dictionary = {}
	for actor_id in active_player_ids:
		targets_by_actor[actor_id] = enemy_ids[0]
	var player_intents: Dictionary = runtime.build_player_intents(session, "light", targets_by_actor)
	assert(str(player_intents.get("status", "")) == "ready")

	var ai_provider = ArenaLimboAIRequestProviderScript.new()
	var ai_requests: Dictionary = ai_provider.build_requests(session, self, self)
	assert(ai_requests.size() == opponent_count)
	for actor_id in enemy_ids:
		assert(ai_requests.has(actor_id))

	var next: Dictionary = runtime.advance_exchange(
		session,
		player_intents.get("player_intents_by_actor", {}) as Dictionary,
		ai_requests,
	)
	assert(
		str(next.get("status", "")) != "rejected",
		"%s must resolve an exchange through LimboAI + CombatSimulator: %s"
		% [format_id, str(next.get("errors", []))]
	)
	var providers := next.get("last_intent_providers", {}) as Dictionary
	for actor_id in enemy_ids:
		assert(str(providers.get(actor_id, "")) == "limboai_policy_template")


func _add_test_gladiator(person_id: String, display_name: String) -> void:
	if RosterManager.get_person(person_id) != null:
		return
	var person := LudusPerson.new(
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
	assert(RosterManager.add_person(person))
