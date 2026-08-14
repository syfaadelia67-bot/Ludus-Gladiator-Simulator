extends RefCounted


func build(session: Dictionary, tournament_summary: Dictionary) -> Dictionary:
	var status := str(session.get("status", ""))
	if status not in ["combat_running", "encounter_finished"]:
		return {
			"status": "invalid",
			"errors": ["GT I presentation requires an active or finished encounter session"],
		}

	var active_loop := session.get("active_loop", {}) as Dictionary
	var state := active_loop.get("state", {}) as Dictionary
	var fighters: Array[Dictionary] = []
	for raw_fighter in state.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		var stats := fighter.get("stats", {}) as Dictionary
		(
			fighters
			. append(
				{
					"id": str(fighter.get("id", "")),
					"team": str(fighter.get("team", "")),
					"current_pv": int(fighter.get("current_pv", stats.get("PV", 0))),
					"max_pv": int(stats.get("PV", 0)),
					"stamina": float(fighter.get("stamina", 0.0)),
					"knocked_out": int(fighter.get("current_pv", stats.get("PV", 0))) <= 0,
				}
			)
		)

	var progress := tournament_summary.get("encounter_progress", {}) as Dictionary
	var month := int(session.get("month", 0))
	return {
		"status": "ready",
		"session_status": status,
		"month": month,
		"encounter": int(session.get("encounter", 0)),
		"format": str(session.get("format", "")),
		"bout_number": mini(3, int(session.get("bout_index", 0)) + 1),
		"completed_bouts": int(session.get("completed_bouts", 0)),
		"encounter_progress": int(progress.get(str(month), 0)),
		"player_wins": int(session.get("player_wins", 0)),
		"player_points": int(session.get("player_points", 0)),
		"tournament_points": int(tournament_summary.get("player_points", 0)),
		"tournament_bouts": int(tournament_summary.get("player_bouts", 0)),
		"fighters": fighters,
		"last_intent_providers":
		(session.get("last_intent_providers", {}) as Dictionary).duplicate(true),
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"presentation_may_mutate_combat": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"input": ["gt1_runtime_session", "tournament_manager_summary"],
		"output": "read_only_ui_snapshot",
		"combat_authority": "combat_simulator",
		"scoring_authority": "tournament_manager",
		"presentation_may_mutate_combat": false,
	}
