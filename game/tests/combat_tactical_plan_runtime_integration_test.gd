extends Node

const ArenaLimboAIRequestProviderScript = preload(
	"res://scripts/combat/arena_limboai_request_provider.gd"
)
const CombatIntentSourceCollectorScript = preload(
	"res://scripts/combat/combat_intent_source_collector.gd"
)
const CombatV1ArenaRuntimeMonthlyScript = preload(
	"res://scripts/ui/combat_v1_arena_runtime_monthly.gd"
)

const FIGHTER_ID := "qa_tactical_runtime_bridge"


func run() -> void:
	DataRepository.load_all()
	assert(NewCampaignCoordinator.reset_campaign_state())
	_add_player_gladiator()
	assert(
		GladiatorProgressionManager.set_tactical_plan(
			FIGHTER_ID, [{"ability_id": "charge", "condition": "always"}]
		)
	)
	var stored_plan := GladiatorProgressionManager.get_tactical_plan(FIGHTER_ID)
	assert(stored_plan.size() == 1)
	assert(str((stored_plan[0] as Dictionary).get("ability_id", "")) == "charge")

	GameState.day = 1
	TournamentManager.prepare_month(1, true)
	var underworld := _underworld_event()
	assert(not underworld.is_empty())
	assert(TournamentManager.accept_event(str(underworld.get("id", "")), FIGHTER_ID))
	var contract := TournamentManager.get_active_contract_for_fighter(FIGHTER_ID)
	assert(not contract.is_empty())

	var runtime = CombatV1ArenaRuntimeMonthlyScript.new()
	var session: Dictionary = runtime.start_non_gt_contract(contract, "player")
	assert(str(session.get("status", "")) == "combat_running")
	var state := _active_state(session)
	assert(not state.is_empty())

	var provider = ArenaLimboAIRequestProviderScript.new()
	var requests: Dictionary = provider.build_requests(session, self, self)
	assert(requests.has(FIGHTER_ID))
	var request := requests.get(FIGHTER_ID, {}) as Dictionary
	var decision_context := request.get("decision_context", {}) as Dictionary
	var requested_plan := decision_context.get("tactical_plan", []) as Array
	assert(requested_plan.size() == 1)
	assert(str((requested_plan[0] as Dictionary).get("ability_id", "")) == "charge")

	var collector = CombatIntentSourceCollectorScript.new()
	collector.set_skill_mechanics(DataRepository.get_skill_mechanics_v1())
	var collected: Dictionary = collector.collect(state, "player", {}, requests)
	assert(
		str(collected.get("status", "")) == "ready",
		"Real Tactical Plan requests must collect through LimboAI without fallback rejection",
	)
	var activations := collected.get("skill_activations_by_actor", {}) as Dictionary
	assert(
		activations.has(FIGHTER_ID),
		"The real collector must preserve the validated Tactical Plan skill activation",
	)
	var activation := activations.get(FIGHTER_ID, {}) as Dictionary
	assert(str(activation.get("skill_id", "")) == "charge")
	assert(str(activation.get("mapped_action_id", "")) == "heavy")
	var intent := _intent_for_actor(collected.get("intents", []) as Array, FIGHTER_ID)
	assert(not intent.is_empty())
	assert(str(intent.get("action_id", "")) == "heavy")
	assert(
		str((intent.get("skill_activation", {}) as Dictionary).get("skill_id", "")) == "charge"
	)

	assert(NewCampaignCoordinator.reset_campaign_state())
	print("Combat Tactical Plan runtime integration bridge: OK")


func _add_player_gladiator() -> void:
	var person := LudusPerson.new(
		{
			"id": FIGHTER_ID,
			"name": "QA Tactical Runtime",
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
	var record := GladiatorProgressionManager.ensure_record(FIGHTER_ID)
	record["abilities"] = {"charge": 1}


func _underworld_event() -> Dictionary:
	for raw_event in TournamentManager.get_available_events():
		if raw_event is Dictionary and str((raw_event as Dictionary).get("competition", "")) == "underworld":
			return (raw_event as Dictionary).duplicate(true)
	return {}


func _active_state(session: Dictionary) -> Dictionary:
	var active_loop := session.get("active_loop", {}) as Dictionary
	return active_loop.get("state", {}) as Dictionary


func _intent_for_actor(intents: Array, actor_id: String) -> Dictionary:
	for raw_intent in intents:
		if raw_intent is Dictionary and str((raw_intent as Dictionary).get("actor_id", "")) == actor_id:
			return (raw_intent as Dictionary).duplicate(true)
	return {}
