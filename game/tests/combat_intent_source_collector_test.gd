extends Node

const CombatIntentSourceCollectorScript = preload(
	"res://scripts/combat/combat_intent_source_collector.gd"
)


func run() -> void:
	_test_player_and_limboai_sources_collect_without_mutation()
	_test_missing_player_source_fails_closed()
	_test_invalid_limboai_proposal_fails_closed()
	_test_stale_inactive_source_fails_closed()
	print("Combat player + LimboAI intent source collector: OK")


func _test_player_and_limboai_sources_collect_without_mutation() -> void:
	var fixture := _runtime_fixture()
	var collector = CombatIntentSourceCollectorScript.new()
	var state := _valid_state()
	var player_intents := {
		"a": {"actor_id": "a", "action_id": "light", "target_id": "b"},
	}
	var ai_proposal := {"actor_id": "b", "action_id": "light", "target_id": "a"}
	var ai_requests := {
		"b":
		{
			"policy_proposal": ai_proposal,
			"agent": fixture.agent,
			"instance_owner": fixture.owner,
		},
	}
	var state_before := state.duplicate(true)
	var player_before := player_intents.duplicate(true)
	var proposal_before := ai_proposal.duplicate(true)

	var result: Dictionary = (
		collector
		. collect(
			state,
			"alpha",
			player_intents,
			ai_requests,
		)
	)
	assert(result.get("status") == "ready")
	assert(result.get("combat_authority") == "combat_simulator")
	assert(result.get("active_actor_ids") == ["a", "b"])
	assert(
		(
			result.get("providers_by_actor")
			== {
				"a": "player",
				"b": "limboai",
			}
		)
	)
	var intents := result.get("intents", []) as Array
	assert(intents.size() == 2)
	assert(str((intents[0] as Dictionary).get("actor_id", "")) == "a")
	assert(str((intents[1] as Dictionary).get("actor_id", "")) == "b")
	assert(state == state_before)
	assert(player_intents == player_before)
	assert(ai_proposal == proposal_before)

	var contract: Dictionary = collector.get_contract()
	assert(contract.get("player_source") == "explicit_desired_action")
	assert(contract.get("ai_source") == "limboai_policy_runner")
	assert(contract.get("default_action_allowed") == false)
	assert(contract.get("policy_may_resolve_combat") == false)
	fixture.owner.free()


func _test_missing_player_source_fails_closed() -> void:
	var fixture := _runtime_fixture()
	var collector = CombatIntentSourceCollectorScript.new()
	var result: Dictionary = (
		collector
		. collect(
			_valid_state(),
			"alpha",
			{},
			{
				"b":
				{
					"policy_proposal": {"actor_id": "b", "action_id": "light", "target_id": "a"},
					"agent": fixture.agent,
					"instance_owner": fixture.owner,
				},
			},
		)
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "invalid_intent_sources")
	assert(_contains_error(result, "Missing player intent source for active fighter a"))
	fixture.owner.free()


func _test_invalid_limboai_proposal_fails_closed() -> void:
	var fixture := _runtime_fixture()
	var collector = CombatIntentSourceCollectorScript.new()
	var result: Dictionary = (
		collector
		. collect(
			_valid_state(),
			"alpha",
			{
				"a": {"actor_id": "a", "action_id": "light", "target_id": "b"},
			},
			{
				"b":
				{
					"policy_proposal":
					{
						"actor_id": "b",
						"action_id": "invented_action",
						"target_id": "a",
					},
					"agent": fixture.agent,
					"instance_owner": fixture.owner,
				},
			},
		)
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "limboai_intent_rejected")
	assert((result.get("intents", []) as Array).is_empty())
	fixture.owner.free()


func _test_stale_inactive_source_fails_closed() -> void:
	var fixture := _runtime_fixture()
	var collector = CombatIntentSourceCollectorScript.new()
	var state := _valid_state()
	(
		(state.get("fighters", []) as Array)
		. append(
			{
				"id": "ko",
				"team": "beta",
				"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
				"current_pv": 0,
				"stamina": 0,
			}
		)
	)
	var result: Dictionary = (
		collector
		. collect(
			state,
			"alpha",
			{
				"a": {"actor_id": "a", "action_id": "light", "target_id": "b"},
			},
			{
				"b":
				{
					"policy_proposal": {"actor_id": "b", "action_id": "light", "target_id": "a"},
					"agent": fixture.agent,
					"instance_owner": fixture.owner,
				},
				"ko":
				{
					"policy_proposal": {"actor_id": "ko", "action_id": "light", "target_id": "a"},
					"agent": fixture.agent,
					"instance_owner": fixture.owner,
				},
			},
		)
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "invalid_intent_sources")
	assert(_contains_error(result, "inactive or unknown fighter ko"))
	fixture.owner.free()


func _valid_state() -> Dictionary:
	return {
		"format": "1v1",
		"fighters":
		[
			_fighter("a", "alpha"),
			_fighter("b", "beta"),
		],
	}


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 10, "PV": 100},
		"stamina": 100,
	}


func _runtime_fixture() -> Dictionary:
	var owner := Node.new()
	var agent := Node.new()
	owner.add_child(agent)
	return {"owner": owner, "agent": agent}


func _contains_error(result: Dictionary, fragment: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
