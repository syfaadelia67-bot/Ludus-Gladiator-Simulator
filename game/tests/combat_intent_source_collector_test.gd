extends Node

const CombatIntentSourceCollectorScript = preload(
	"res://scripts/combat/combat_intent_source_collector.gd"
)


func run() -> void:
	_test_limboai_sources_collect_for_both_teams_without_mutation()
	_test_legacy_player_source_remains_compatible()
	_test_missing_source_fails_closed()
	_test_invalid_limboai_proposal_fails_closed()
	_test_stale_inactive_source_fails_closed()
	print("Combat LimboAI intent source collector: OK")


func _test_limboai_sources_collect_for_both_teams_without_mutation() -> void:
	var fixture := _runtime_fixture()
	var collector = CombatIntentSourceCollectorScript.new()
	var state := _valid_state()
	var proposals := {
		"a": {"actor_id": "a", "action_id": "light", "target_id": "b"},
		"b": {"actor_id": "b", "action_id": "light", "target_id": "a"},
	}
	var ai_requests := {
		"a": _request(proposals["a"], fixture),
		"b": _request(proposals["b"], fixture),
	}
	var state_before := state.duplicate(true)
	var proposals_before := proposals.duplicate(true)

	var result: Dictionary = collector.collect(state, "alpha", {}, ai_requests)
	assert(result.get("status") == "ready")
	assert(result.get("combat_authority") == "combat_simulator")
	assert(result.get("active_actor_ids") == ["a", "b"])
	assert(result.get("providers_by_actor") == {"a": "limboai", "b": "limboai"})
	var intents := result.get("intents", []) as Array
	assert(intents.size() == 2)
	assert(str((intents[0] as Dictionary).get("actor_id", "")) == "a")
	assert(str((intents[1] as Dictionary).get("actor_id", "")) == "b")
	assert(state == state_before)
	assert(proposals == proposals_before)

	var contract: Dictionary = collector.get_contract()
	assert(contract.get("primary_source") == "limboai_policy_runner")
	assert(contract.get("legacy_player_source") == "explicit_desired_action")
	assert(contract.get("limboai_allowed_for_player_fighters") == true)
	assert(contract.get("limboai_allowed_for_rival_fighters") == true)
	assert(contract.get("default_action_allowed") == false)
	assert(contract.get("policy_may_resolve_combat") == false)
	fixture.owner.free()


func _test_legacy_player_source_remains_compatible() -> void:
	var fixture := _runtime_fixture()
	var collector = CombatIntentSourceCollectorScript.new()
	var result: Dictionary = (
		collector
		. collect(
			_valid_state(),
			"alpha",
			{"a": {"actor_id": "a", "action_id": "light", "target_id": "b"}},
			{"b": _request({"actor_id": "b", "action_id": "light", "target_id": "a"}, fixture)},
		)
	)
	assert(result.get("status") == "ready")
	assert(
		result.get("providers_by_actor") == {"a": "player_legacy", "b": "limboai"},
		"Legacy explicit player intents may remain compatible but are not the Arena runtime source",
	)
	fixture.owner.free()


func _test_missing_source_fails_closed() -> void:
	var fixture := _runtime_fixture()
	var collector = CombatIntentSourceCollectorScript.new()
	var result: Dictionary = (
		collector
		. collect(
			_valid_state(),
			"alpha",
			{},
			{"b": _request({"actor_id": "b", "action_id": "light", "target_id": "a"}, fixture)},
		)
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "invalid_intent_sources")
	assert(_contains_error(result, "Missing intent source for active fighter a"))
	fixture.owner.free()


func _test_invalid_limboai_proposal_fails_closed() -> void:
	var fixture := _runtime_fixture()
	var collector = CombatIntentSourceCollectorScript.new()
	var result: Dictionary = (
		collector
		. collect(
			_valid_state(),
			"alpha",
			{},
			{
				"a": _request({"actor_id": "a", "action_id": "light", "target_id": "b"}, fixture),
				"b":
				_request(
					{"actor_id": "b", "action_id": "invented_action", "target_id": "a"}, fixture
				),
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
	var result: Dictionary = (
		collector
		. collect(
			_valid_2v2_state_with_knocked_out_beta(),
			"alpha",
			{},
			{
				"a": _request({"actor_id": "a", "action_id": "light", "target_id": "b"}, fixture),
				"a2": _request({"actor_id": "a2", "action_id": "light", "target_id": "b"}, fixture),
				"b": _request({"actor_id": "b", "action_id": "light", "target_id": "a"}, fixture),
				"ko": _request({"actor_id": "ko", "action_id": "light", "target_id": "a"}, fixture),
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
		"fighters": [_fighter("a", "alpha"), _fighter("b", "beta")],
	}


func _valid_2v2_state_with_knocked_out_beta() -> Dictionary:
	var knocked_out := _fighter("ko", "beta")
	knocked_out["current_pv"] = 0
	knocked_out["stamina"] = 0
	return {
		"format": "2v2",
		"fighters":
		[
			_fighter("a", "alpha"),
			_fighter("a2", "alpha"),
			_fighter("b", "beta"),
			knocked_out,
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


func _request(proposal: Dictionary, fixture: Dictionary) -> Dictionary:
	return {
		"policy_proposal": proposal.duplicate(true),
		"agent": fixture.agent,
		"instance_owner": fixture.owner,
	}


func _contains_error(result: Dictionary, fragment: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
