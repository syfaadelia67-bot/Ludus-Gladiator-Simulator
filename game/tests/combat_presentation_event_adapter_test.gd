extends Node

const CombatPresentationEventAdapterScript = preload(
	"res://scripts/combat/combat_presentation_event_adapter.gd"
)


func _ready() -> void:
	var adapter = CombatPresentationEventAdapterScript.new()
	_assert_contract(adapter)
	_assert_resolved_exchange_is_projected_without_new_math(adapter)
	_assert_skill_activation_is_projected_from_resolved_intent(adapter)
	_assert_unresolved_input_emits_nothing(adapter)
	print("Combat presentation event adapter: OK")
	get_tree().quit(0)


func _assert_contract(adapter) -> void:
	var contract: Dictionary = adapter.get_contract()
	assert(str(contract.get("status", "")) == "frozen")
	assert(str(contract.get("input_authority", "")) == "combat_simulator_exchange_result")
	assert(str(contract.get("output_role", "")) == "presentation_only")
	assert(contract.get("damage_math_allowed") == false)
	assert(contract.get("hit_math_allowed") == false)
	assert(contract.get("stamina_math_allowed") == false)
	assert(contract.get("winner_math_allowed") == false)
	assert(contract.get("intent_selection_allowed") == false)
	var event_types := contract.get("events", []) as Array
	assert(event_types.has("stamina_spent"))
	assert(event_types.has("stamina_recovered"))


func _assert_resolved_exchange_is_projected_without_new_math(adapter) -> void:
	var exchange_result := {
		"status": "resolved",
		"submitted_intents":
		[
			{"actor_id": "a", "action_id": "light", "target_id": "b"},
			{"actor_id": "b", "action_id": "block"},
		],
		"stamina_spend_results":
		[
			{
				"status": "resolved",
				"action_id": "light",
				"cost": 3,
				"fighter": {"id": "a", "stamina": 7.0},
			},
			{
				"status": "resolved",
				"action_id": "block",
				"cost": 2,
				"fighter": {"id": "b", "stamina": 8.0},
			},
		],
		"attack_results":
		[
			{
				"actor_id": "a",
				"target_id": "b",
				"action_id": "light",
				"skill_id": "",
				"hit": true,
				"damage": 7,
				"defense_action_id": "block",
				"intercepted": false,
				"interceptor_id": "",
			}
		],
		"ko_fighter_ids": ["b"],
		"stamina_recovery_results":
		[
			{
				"status": "resolved",
				"recovery": 2,
				"timing": "end_exchange",
				"fighter": {"id": "a", "stamina": 9.0},
			},
			{
				"status": "resolved",
				"recovery": 2,
				"timing": "end_exchange",
				"fighter": {"id": "b", "stamina": 10.0},
			},
		],
		"combat_end_resolved": true,
		"outcome": "team_win",
		"winner_team_id": "alpha",
		"loser_team_id": "beta",
	}
	var before := exchange_result.duplicate(true)
	var events: Array[Dictionary] = adapter.build_exchange_events(4, exchange_result)
	assert(exchange_result == before, "Presentation projection must never mutate simulator output")
	assert(events.size() == 10)
	assert(str(events[0].get("type", "")) == "exchange_started")
	assert(int(events[0].get("exchange_index", 0)) == 4)
	assert(str(events[1].get("type", "")) == "action_declared")
	assert(str(events[2].get("type", "")) == "action_declared")
	assert(str(events[3].get("type", "")) == "stamina_spent")
	assert(str(events[3].get("fighter_id", "")) == "a")
	assert(int(events[3].get("cost", -1)) == 3)
	assert(float(events[3].get("stamina_after", -1.0)) == 7.0)
	assert(str(events[4].get("type", "")) == "stamina_spent")
	assert(str(events[5].get("type", "")) == "attack_resolved")
	assert(int(events[5].get("damage", -1)) == 7)
	assert(events[5].get("hit") == true)
	assert(str(events[6].get("type", "")) == "fighter_knocked_out")
	assert(str(events[6].get("fighter_id", "")) == "b")
	assert(str(events[7].get("type", "")) == "stamina_recovered")
	assert(str(events[7].get("fighter_id", "")) == "a")
	assert(int(events[7].get("amount", -1)) == 2)
	assert(float(events[7].get("stamina_after", -1.0)) == 9.0)
	assert(str(events[8].get("type", "")) == "stamina_recovered")
	assert(str(events[9].get("type", "")) == "combat_finished")
	assert(str(events[9].get("winner_team_id", "")) == "alpha")
	assert(str(events[9].get("loser_team_id", "")) == "beta")


func _assert_skill_activation_is_projected_from_resolved_intent(adapter) -> void:
	var exchange_result := {
		"status": "resolved",
		"submitted_intents":
		[
			{
				"actor_id": "a",
				"action_id": "heavy",
				"target_id": "b",
				"skill_activation": {"skill_id": "charge", "rank": 1},
			},
		],
		"stamina_spend_results": [],
		"attack_results": [],
		"ko_fighter_ids": [],
		"stamina_recovery_results": [],
		"combat_end_resolved": false,
	}
	var before := exchange_result.duplicate(true)
	var events: Array[Dictionary] = adapter.build_exchange_events(2, exchange_result)
	assert(exchange_result == before, "Skill projection must not mutate simulator output")
	assert(events.size() == 2)
	assert(str(events[1].get("type", "")) == "action_declared")
	assert(str(events[1].get("skill_id", "")) == "charge")
	assert(str(events[1].get("action_id", "")) == "heavy")


func _assert_unresolved_input_emits_nothing(adapter) -> void:
	assert(adapter.build_exchange_events(1, {"status": "rejected"}).is_empty())
	assert(adapter.build_exchange_events(1, {}).is_empty())
