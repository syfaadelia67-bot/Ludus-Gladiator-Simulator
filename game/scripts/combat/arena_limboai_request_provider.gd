extends RefCounted


func build_requests(session: Dictionary, agent: Node, instance_owner: Node) -> Dictionary:
	var active_loop_value: Variant = session.get("active_loop", null)
	if not active_loop_value is Dictionary:
		return {}
	var active_loop := active_loop_value as Dictionary
	var state_value: Variant = active_loop.get("state", null)
	if not state_value is Dictionary:
		return {}
	if agent == null or instance_owner == null:
		return {}

	var state := state_value as Dictionary
	var player_team_id := str(session.get("player_team_id", ""))
	if player_team_id.is_empty():
		return {}

	var fighters: Array[Dictionary] = []
	for raw_fighter in state.get("fighters", []) as Array:
		if raw_fighter is not Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		if not _is_active(fighter):
			continue
		if str(fighter.get("id", "")).is_empty():
			continue
		fighters.append(fighter)
	fighters.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("id", "")) < str(b.get("id", ""))
	)

	var requests: Dictionary = {}
	for fighter in fighters:
		var actor_id := str(fighter.get("id", ""))
		var tactical_plan: Array = []
		if str(fighter.get("team", "")) == player_team_id:
			tactical_plan = GladiatorProgressionManager.get_tactical_plan(actor_id)
		requests[actor_id] = {
			"policy_proposal": {"actor_id": actor_id, "auto_select": true},
			"decision_context":
			{
				"tactical_plan": tactical_plan.duplicate(true),
				"exchange_index": int(active_loop.get("exchange_index", 0)),
				"last_exchange_result":
				(active_loop.get("last_exchange_result", {}) as Dictionary).duplicate(true),
			},
			"agent": agent,
			"instance_owner": instance_owner,
		}
	return requests


func _is_active(fighter: Dictionary) -> bool:
	var stats := fighter.get("stats", {}) as Dictionary
	return int(fighter.get("current_pv", stats.get("PV", 0))) > 0
