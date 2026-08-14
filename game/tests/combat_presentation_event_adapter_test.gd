extends Node

const CombatPresentationEventAdapterScript = preload(
	"res://scripts/combat/combat_presentation_event_adapter.gd"
)


func _ready() -> void:
	var adapter = CombatPresentationEventAdapterScript.new()
	_assert_contract(adapter)
	_assert_resolved_exchange_is_projected_without_new_math(adapter)
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
	assert(contract.get("winner_math_allowed") == false)
	assert(contract.get("intent_selection_allowed") == false)


func _assert_resolved_exchange_is_projected_without_new_math(adapter) -> void:
	var exchange_result := {
		"status": "resolved",
		"submitted_intents":
		[
			{"actor_id": "a", "action_id": "light", "target_id": "b"},
			{"actor_id": "b", "action_id": "block"},
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
		"combat_end_resolved": true,
		"outcome": "team_win",
		"winner_team_id": "alpha",
		"loser_team_id": "beta",
	}
	var before := exchange_result.duplicate(true)
	var events: Array[Dictionary] = adapter.build_exchange_events(4, exchange_result)
	assert(exchange_result == before, "Presentation projection must never mutate simulator output")
	assert(events.size() == 6)
	assert(str(events[0].get("type", "")) == "exchange_started")
	assert(int(events[0].get("exchange_index", 0)) == 4)
	assert(str(events[1].get("type", "")) == "action_declared")
	assert(str(events[2].get("type", "")) == "action_declared")
	assert(str(events[3].get("type", "")) == "attack_resolved")
	assert(int(events[3].get("damage", -1)) == 7)
	assert(events[3].get("hit") == true)
	assert(str(events[4].get("type", "")) == "fighter_knocked_out")
	assert(str(events[4].get("fighter_id", "")) == "b")
	assert(str(events[5].get("type", "")) == "combat_finished")
	assert(str(events[5].get("winner_team_id", "")) == "alpha")
	assert(str(events[5].get("loser_team_id", "")) == "beta")


func _assert_unresolved_input_emits_nothing(adapter) -> void:
	assert(adapter.build_exchange_events(1, {"status": "rejected"}).is_empty())
	assert(adapter.build_exchange_events(1, {}).is_empty())
