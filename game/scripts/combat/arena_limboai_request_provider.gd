extends RefCounted


func build_requests(session: Dictionary, agent: Node, instance_owner: Node) -> Dictionary:
	var active_loop_value: Variant = session.get("active_loop", null)
	if not active_loop_value is Dictionary:
		return {}
	var state_value: Variant = (active_loop_value as Dictionary).get("state", null)
	if not state_value is Dictionary:
		return {}
	if agent == null or instance_owner == null:
		return {}

	var state := state_value as Dictionary
	var player_team_id := str(session.get("player_team_id", ""))
	if player_team_id.is_empty():
		return {}

	var player_ids: Array[String] = []
	var enemy_fighters: Array[Dictionary] = []
	for raw_fighter in state.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		if not _is_active(fighter):
			continue
		var fighter_id := str(fighter.get("id", ""))
		if fighter_id.is_empty():
			continue
		if str(fighter.get("team", "")) == player_team_id:
			player_ids.append(fighter_id)
		else:
			enemy_fighters.append(fighter)

	player_ids.sort()
	enemy_fighters.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", "")) < str(b.get("id", ""))
	)
	if player_ids.is_empty():
		return {}

	var requests: Dictionary = {}
	for fighter in enemy_fighters:
		var actor_id := str(fighter.get("id", ""))
		var action_id := _select_legal_action(fighter)
		var proposal := {
			"actor_id": actor_id,
			"action_id": action_id,
		}
		if action_id in ["light", "heavy"]:
			proposal["target_id"] = player_ids[0]
		requests[actor_id] = {
			"policy_proposal": proposal,
			"agent": agent,
			"instance_owner": instance_owner,
		}
	return requests


func _select_legal_action(fighter: Dictionary) -> String:
	var stamina := float(fighter.get("stamina", 0.0))
	if stamina >= 3.0:
		return "light"
	return "block"


func _is_active(fighter: Dictionary) -> bool:
	var stats := fighter.get("stats", {}) as Dictionary
	return int(fighter.get("current_pv", stats.get("PV", 0))) > 0
