extends "res://scripts/systems/combat_history_manager.gd"


func _ready() -> void:
	# Canonical demo history is registered explicitly by Combat V1 runtimes.
	# Do not subscribe to the quarantined legacy CombatManager signal.
	pass


func register_gt1_bout(
	month: int,
	encounter: int,
	bout_number: int,
	player_team_id: String,
	combat_result: Dictionary,
	tournament_result: Dictionary
) -> Dictionary:
	if month < 1 or player_team_id.is_empty():
		return {}
	if combat_result.get("status") != "combat_finished":
		return {}
	if tournament_result.is_empty():
		return {}

	var state := combat_result.get("state", {}) as Dictionary
	var player_fighters: Array[Dictionary] = []
	var opponent_fighters: Array[Dictionary] = []
	for raw_fighter in state.get("fighters", []) as Array:
		if not raw_fighter is Dictionary:
			continue
		var fighter := raw_fighter as Dictionary
		if str(fighter.get("team", "")) == player_team_id:
			player_fighters.append(fighter)
		else:
			opponent_fighters.append(fighter)
	if player_fighters.is_empty() or opponent_fighters.is_empty():
		return {}

	var player_ids := _fighter_ids(player_fighters)
	var opponent_ids := _fighter_ids(opponent_fighters)
	var player_health := _total_current_pv(player_fighters)
	var player_max_health := _total_max_pv(player_fighters)
	var player_won := (
		str(combat_result.get("outcome", "")) == "team_win"
		and str(combat_result.get("winner_team_id", "")) == player_team_id
	)
	var legacy_result := {
		"victory": player_won,
		"surrendered": false,
		"event_type": "official",
		"event_name": "Gran Torneo de Roma · Encuentro %d · Combate %d" % [encounter, bout_number],
		"fighter": _fighter_label(player_fighters),
		"fighter_id": str(player_ids[0]),
		"enemy": _fighter_label(opponent_fighters),
		"enemy_kind": _enemy_kind(opponent_fighters),
		"rounds": int(combat_result.get("exchange_index", 0)),
		"reward": 0,
		"reputation": 0,
		"injury": "",
		"tactic": "combat_v1",
		"player_health": player_health,
		"player_max_health": maxi(1, player_max_health),
		"technique_stats": {},
		"status_stats": {},
	}
	super._on_combat_finished(legacy_result)
	if entries.is_empty():
		return {}

	var entry := entries[0]
	entry["month"] = month
	entry["week"] = month
	entry["day"] = month
	entry["competition"] = "grand_tournament"
	entry["encounter"] = encounter
	entry["bout_number"] = bout_number
	entry["format"] = str(state.get("format", ""))
	entry["player_team_id"] = player_team_id
	entry["player_fighter_ids"] = player_ids.duplicate()
	entry["opponent_fighter_ids"] = opponent_ids.duplicate()
	entry["outcome"] = str(combat_result.get("outcome", ""))
	entry["winner_team_id"] = str(combat_result.get("winner_team_id", ""))
	entry["double_ko"] = str(combat_result.get("outcome", "")) == "double_ko"
	entry["points_gained"] = int(tournament_result.get("points_gained", 0))
	entry["result_authority"] = "combat_simulator"
	entry["scoring_authority"] = "TournamentManager"
	entries[0] = entry
	history_changed.emit()
	return entry.duplicate(true)


func import_state(data: Dictionary, current_day: int = -1) -> void:
	var migrated := data.duplicate(true)
	var migrated_entries: Array = []
	for raw_entry in data.get("entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		var month := maxi(1, int(entry.get("month", entry.get("week", entry.get("day", 1)))))
		entry["month"] = month
		entry["week"] = month
		entry["day"] = month
		migrated_entries.append(entry)
	migrated["entries"] = migrated_entries
	var effective_month := current_day if current_day >= 1 else GameState.get_month()
	super.import_state(migrated, effective_month)


func get_entries() -> Array[Dictionary]:
	var result := super.get_entries()
	for entry in result:
		if entry is Dictionary:
			var month := maxi(1, int(entry.get("month", entry.get("week", entry.get("day", 1)))))
			entry["month"] = month
			entry["week"] = month
			entry["day"] = month
	return result


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"authority": "combat_history_observer_only",
		"period": "month",
		"canonical_source": "gt1_combat_runtime_after_combat_simulator_result",
		"result_authority": false,
		"scoring_authority": false,
		"legacy_combat_manager_subscription": false,
		"month_field_canonical": true,
		"week_day_fields_compatibility_aliases": true,
		"save_version_change_required": false,
	}


func _fighter_ids(fighters: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for fighter in fighters:
		result.append(str(fighter.get("id", "")))
	return result


func _fighter_label(fighters: Array[Dictionary]) -> String:
	var labels: Array[String] = []
	for fighter in fighters:
		var fighter_id := str(fighter.get("id", ""))
		labels.append(str(fighter.get("name", fighter.get("display_name", fighter_id))))
	return " + ".join(labels)


func _total_current_pv(fighters: Array[Dictionary]) -> int:
	var total := 0
	for fighter in fighters:
		var stats := fighter.get("stats", {}) as Dictionary
		total += maxi(0, int(fighter.get("current_pv", stats.get("PV", 0))))
	return total


func _total_max_pv(fighters: Array[Dictionary]) -> int:
	var total := 0
	for fighter in fighters:
		var stats := fighter.get("stats", {}) as Dictionary
		total += maxi(1, int(stats.get("PV", 1)))
	return total


func _enemy_kind(fighters: Array[Dictionary]) -> String:
	for fighter in fighters:
		if str(fighter.get("kind", fighter.get("fighter_kind", ""))) == "beast":
			return "beast"
	return "gladiator"
