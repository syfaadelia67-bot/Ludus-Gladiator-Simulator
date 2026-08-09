extends RefCounted

const CombatIntentSourceCollectorScript = preload(
	"res://scripts/combat/combat_intent_source_collector.gd"
)
const GT1CombatRuntimeScript = preload("res://scripts/combat/gt1_combat_runtime.gd")

var _collector = CombatIntentSourceCollectorScript.new()
var _runtime = GT1CombatRuntimeScript.new()


func advance_exchange(
	session: Dictionary, player_intents_by_actor: Dictionary, ai_requests_by_actor: Dictionary
) -> Dictionary:
	if str(session.get("status", "")) != "combat_running":
		return _rejected(
			"invalid_gt1_session",
			["GT I intent bridge requires a combat_running session"],
			session,
		)
	var player_team_id := str(session.get("player_team_id", ""))
	var active_loop_value: Variant = session.get("active_loop", null)
	if player_team_id.is_empty() or not active_loop_value is Dictionary:
		return _rejected(
			"invalid_gt1_session",
			["GT I intent bridge requires player_team_id and active_loop"],
			session,
		)
	var active_loop := active_loop_value as Dictionary
	var state_value: Variant = active_loop.get("state", null)
	if not state_value is Dictionary:
		return _rejected(
			"invalid_gt1_session",
			["GT I active loop requires CombatState"],
			session,
		)

	var collection: Dictionary = (
		_collector
		. collect(
			state_value as Dictionary,
			player_team_id,
			player_intents_by_actor,
			ai_requests_by_actor,
		)
	)
	if collection.get("status") != "ready":
		return _rejected(
			"gt1_intent_collection_failed",
			collection.get("errors", []) as Array,
			session,
		)

	var next: Dictionary = (
		_runtime
		. advance_exchange(
			session,
			collection.get("intents", []) as Array,
		)
	)
	if next.get("status") == "rejected":
		return next
	next["last_intent_providers"] = (
		(collection.get("providers_by_actor", {}) as Dictionary).duplicate(true)
	)
	next["last_intent_actor_ids"] = (collection.get("active_actor_ids", []) as Array).duplicate()
	next["intent_collection_authority"] = "combat_intent_source_collector"
	next["combat_authority"] = "combat_simulator"
	return next


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"player_intents": "explicit_desired_actions",
		"ai_intents": "limboai_policy_runner",
		"collector": "combat_intent_source_collector",
		"runtime": "gt1_combat_runtime",
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"bridge_may_resolve_combat": false,
	}


func _rejected(reason: String, errors: Array, session: Dictionary) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"session": session.duplicate(true),
		"last_intent_providers": {},
		"last_intent_actor_ids": [],
		"intent_collection_authority": "combat_intent_source_collector",
		"combat_authority": "combat_simulator",
	}
