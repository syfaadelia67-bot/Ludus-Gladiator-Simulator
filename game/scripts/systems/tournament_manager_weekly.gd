extends "res://scripts/systems/tournament_manager.gd"

signal monthly_tournaments_processed(results: Array)
signal grand_tournament_changed(summary: Dictionary)

# Compatibility signal while weekly consumers are migrated.
signal weekly_tournaments_processed(results: Array)

const GT1_ID := "grand_tournament_rome"
const GT1_NAME := "Gran Torneo de Roma"
const GT1_ENCOUNTER_MONTHS := [13, 16, 20]
const GT1_BOUTS_PER_ENCOUNTER := 3
const GT1_TOTAL_BOUTS := 9
const GT1_POINTS_PER_WIN := 3
const GT1_RIVAL_COUNT := 7

const MINOR_PRIZES := {
	1: {"champion": 150, "eliminated": 25, "reputation": 25, "points": 2},
	2: {"champion": 200, "eliminated": 35, "reputation": 40, "points": 3},
	3: {"champion": 275, "eliminated": 50, "reputation": 60, "points": 4},
}

const GT1_ENCOUNTERS := {
	13: {
		"encounter": 1,
		"format": "1v1",
		"team_size": 1,
		"opponent_count": 1,
		"series_bouts": 3,
		"consecutive": true,
		"same_roster": true,
		"allows_beasts": false,
		"substitutions": 0,
		"description": "Tres 1v1 consecutivos con el mismo gladiador.",
	},
	16: {
		"encounter": 2,
		"format": "1v1",
		"team_size": 1,
		"opponent_count": 1,
		"series_bouts": 3,
		"consecutive": false,
		"same_roster": false,
		"allows_beasts": true,
		"substitutions": 0,
		"description": "Tres 1v1 independientes; se permiten gladiadores y bestias.",
	},
	20: {
		"encounter": 3,
		"format": "2v2",
		"team_size": 2,
		"opponent_count": 2,
		"series_bouts": 3,
		"consecutive": true,
		"same_roster": true,
		"allows_beasts": false,
		"substitutions": 1,
		"description": "Tres 2v2 consecutivos con la misma pareja y una sustitución unilateral.",
	},
}

var gt1_player_points: int = 0
var gt1_player_wins: int = 0
var gt1_player_bouts: int = 0
var gt1_encounter_progress: Dictionary = {"13": 0, "16": 0, "20": 0}
var gt1_rival_scores: Dictionary = {}
var gt1_standings: Array[Dictionary] = []
var gt1_placement: int = 0
var gt1_medal: String = ""
var gt1_standings_resolved: bool = false
var gt1_tiebreak_required: bool = false


func _ready() -> void:
	prepare_month(GameState.get_month())


func generate_calendar() -> void:
	prepare_month(GameState.get_month(), true)


func prepare_month(month: int, force: bool = false) -> void:
	var resolved_month := maxi(1, month)
	if not force and _calendar_matches_month(resolved_month):
		return
	available_events.clear()
	for event in _build_month_schedule(resolved_month):
		available_events.append(event)
	calendar_changed.emit()


func get_month_schedule(month: int = 0) -> Array:
	var resolved_month := GameState.get_month() if month <= 0 else maxi(1, month)
	return _build_month_schedule(resolved_month).duplicate(true)


func is_grand_tournament_month(month: int) -> bool:
	return GT1_ENCOUNTER_MONTHS.has(month)


func get_gt1_encounter(month: int = 0) -> Dictionary:
	var resolved_month := GameState.get_month() if month <= 0 else month
	if not GT1_ENCOUNTERS.has(resolved_month):
		return {}
	var data: Dictionary = GT1_ENCOUNTERS[resolved_month].duplicate(true)
	data["tournament_id"] = GT1_ID
	data["tournament_name"] = GT1_NAME
	data["month"] = resolved_month
	data["points_per_win"] = GT1_POINTS_PER_WIN
	return data


func accept_event(event_id: String, fighter_id: String) -> bool:
	var event := _find_event(event_id)
	if event.is_empty():
		contract_failed.emit("El evento seleccionado ya no está disponible.")
		return false
	if int(event.get("scheduled_month", GameState.get_month())) != GameState.get_month():
		contract_failed.emit("Solo podés inscribirte en competiciones del mes actual.")
		return false
	if bool(event.get("requires_team_selection", false)):
		contract_failed.emit("Este encuentro requiere seleccionar una pareja 2v2.")
		return false
	if not super.accept_event(event_id, fighter_id):
		return false
	var contract := _find_contract(event_id)
	if not contract.is_empty():
		var scheduled_month := _scheduled_month(contract)
		contract["scheduled_month"] = scheduled_month
		contract["scheduled_week"] = scheduled_month
		contract["scheduled_day"] = scheduled_month
		contract["accepted_month"] = GameState.get_month()
		contract["accepted_week"] = GameState.get_month()
		contract["accepted_day"] = GameState.get_month()
		contract["bouts_resolved"] = 0
	return true


func get_active_contract_for_fighter(fighter_id: String) -> Dictionary:
	for contract in active_contracts:
		if (
			str(contract.get("fighter_id", "")) == fighter_id
			and _scheduled_month(contract) == GameState.get_month()
		):
			return contract.duplicate(true)
	return {}


func process_month() -> Array:
	var results: Array = []
	var current_month := GameState.get_month()
	for contract in active_contracts.duplicate():
		if _scheduled_month(contract) > current_month:
			continue
		var forfeit := _resolve_monthly_forfeit(contract, current_month)
		results.append(forfeit)
		active_contracts.erase(contract)
		history.push_front(forfeit.duplicate(true))
		tournament_resolved.emit(forfeit)

	if is_grand_tournament_month(current_month):
		_close_gt1_encounter(current_month)

	if not results.is_empty():
		calendar_changed.emit()
	monthly_tournaments_processed.emit(results.duplicate(true))
	weekly_tournaments_processed.emit(results.duplicate(true))
	return results


func process_week() -> Array:
	return process_month()


func process_day() -> Array:
	return process_month()


func register_combat_result(fighter_id: String, victory: bool) -> Dictionary:
	var matching := _find_due_contract_for_fighter(fighter_id)
	if matching.is_empty():
		return {}

	var competition := str(matching.get("competition", "official_minor"))
	var result: Dictionary = matching.duplicate(true)
	result["victory"] = victory
	result["resolved_month"] = GameState.get_month()
	result["resolved_week"] = GameState.get_month()
	result["resolved_day"] = GameState.get_month()

	if competition == "grand_tournament":
		var gt_result := register_grand_tournament_fight_result(victory, GameState.get_month())
		if gt_result.is_empty():
			return {}
		matching["bouts_resolved"] = int(matching.get("bouts_resolved", 0)) + 1
		result.merge(gt_result, true)
		if int(matching.get("bouts_resolved", 0)) >= int(matching.get("series_bouts", 3)):
			active_contracts.erase(matching)
	elif competition == "underworld":
		var bouts := int(matching.get("bouts_resolved", 0)) + 1
		matching["bouts_resolved"] = bouts
		var reward := 60 if victory else 0
		if victory:
			GameState.denarii += reward
		result["reward_paid"] = reward
		result["reputation_change"] = 0
		result["status"] = "victoria" if victory else "derrota"
		if not victory or bouts >= int(matching.get("series_bouts", 10)):
			active_contracts.erase(matching)
	else:
		var tier := clampi(int(matching.get("tournament_tier", 1)), 1, 3)
		var prizes: Dictionary = MINOR_PRIZES[tier]
		var reward := int(prizes.get("champion", 0)) if victory else int(prizes.get("eliminated", 0))
		var reputation_change := int(prizes.get("reputation", 0)) if victory else 0
		GameState.denarii += reward
		GameState.reputation += reputation_change
		result["reward_paid"] = reward
		result["reputation_change"] = reputation_change
		result["points"] = int(prizes.get("points", 0)) if victory else 0
		result["status"] = "victoria" if victory else "derrota"
		active_contracts.erase(matching)

	if competition != "grand_tournament":
		history.push_front(result.duplicate(true))
		tournament_resolved.emit(result.duplicate(true))
	GameState.resources_changed.emit()
	calendar_changed.emit()
	return result


func register_grand_tournament_fight_result(
	victory: bool, month: int = 0, forfeit: bool = false
) -> Dictionary:
	var resolved_month := GameState.get_month() if month <= 0 else month
	if not is_grand_tournament_month(resolved_month):
		return {}
	var key := str(resolved_month)
	var encounter_bouts := int(gt1_encounter_progress.get(key, 0))
	if encounter_bouts >= GT1_BOUTS_PER_ENCOUNTER:
		return {}

	gt1_encounter_progress[key] = encounter_bouts + 1
	gt1_player_bouts += 1
	var points_gained := 0
	if victory:
		gt1_player_wins += 1
		gt1_player_points += GT1_POINTS_PER_WIN
		points_gained = GT1_POINTS_PER_WIN

	var result := {
		"competition": "grand_tournament",
		"tournament_id": GT1_ID,
		"tournament_name": GT1_NAME,
		"month": resolved_month,
		"encounter": int(GT1_ENCOUNTERS[resolved_month].get("encounter", 0)),
		"bout": encounter_bouts + 1,
		"victory": victory,
		"forfeit": forfeit,
		"points_gained": points_gained,
		"player_points": gt1_player_points,
		"player_wins": gt1_player_wins,
		"player_bouts": gt1_player_bouts,
	}
	history.push_front(result.duplicate(true))
	tournament_resolved.emit(result.duplicate(true))
	_finalize_gt1_standings_if_ready()
	grand_tournament_changed.emit(get_gt1_summary())
	return result


func register_gt1_rival_result(rival_id: String, rival_name: String, points: int, wins: int) -> bool:
	if rival_id.is_empty() or rival_id == "player":
		return false
	gt1_rival_scores[rival_id] = {
		"id": rival_id,
		"name": rival_name if not rival_name.is_empty() else rival_id,
		"points": clampi(points, 0, 27),
		"wins": clampi(wins, 0, GT1_TOTAL_BOUTS),
	}
	_finalize_gt1_standings_if_ready()
	grand_tournament_changed.emit(get_gt1_summary())
	return true


func get_gt1_summary() -> Dictionary:
	return {
		"id": GT1_ID,
		"name": GT1_NAME,
		"encounter_months": GT1_ENCOUNTER_MONTHS.duplicate(),
		"points_per_win": GT1_POINTS_PER_WIN,
		"player_points": gt1_player_points,
		"player_wins": gt1_player_wins,
		"player_bouts": gt1_player_bouts,
		"encounter_progress": gt1_encounter_progress.duplicate(true),
		"player_series_complete": gt1_player_bouts >= GT1_TOTAL_BOUTS,
		"rival_results_registered": gt1_rival_scores.size(),
		"standings_resolved": gt1_standings_resolved,
		"tiebreak_required": gt1_tiebreak_required,
		"placement": gt1_placement,
		"medal": gt1_medal,
		"standings": gt1_standings.duplicate(true),
	}


func is_gt1_complete() -> bool:
	return gt1_standings_resolved


func get_gt1_medal() -> String:
	return gt1_medal


func export_state() -> Dictionary:
	var data := super.export_state()
	data["gt1_player_points"] = gt1_player_points
	data["gt1_player_wins"] = gt1_player_wins
	data["gt1_player_bouts"] = gt1_player_bouts
	data["gt1_encounter_progress"] = gt1_encounter_progress.duplicate(true)
	data["gt1_rival_scores"] = gt1_rival_scores.duplicate(true)
	data["gt1_standings"] = gt1_standings.duplicate(true)
	data["gt1_placement"] = gt1_placement
	data["gt1_medal"] = gt1_medal
	data["gt1_standings_resolved"] = gt1_standings_resolved
	data["gt1_tiebreak_required"] = gt1_tiebreak_required
	return data


func import_state(data: Dictionary) -> void:
	super.import_state(data)
	_migrate_month_fields(available_events)
	_migrate_month_fields(active_contracts)
	_migrate_month_fields(history)
	gt1_player_points = clampi(int(data.get("gt1_player_points", 0)), 0, 27)
	gt1_player_wins = clampi(int(data.get("gt1_player_wins", 0)), 0, GT1_TOTAL_BOUTS)
	gt1_player_bouts = clampi(int(data.get("gt1_player_bouts", 0)), 0, GT1_TOTAL_BOUTS)
	gt1_encounter_progress = {"13": 0, "16": 0, "20": 0}
	var saved_progress: Dictionary = data.get("gt1_encounter_progress", {})
	for month in GT1_ENCOUNTER_MONTHS:
		var key := str(month)
		gt1_encounter_progress[key] = clampi(
			int(saved_progress.get(key, 0)), 0, GT1_BOUTS_PER_ENCOUNTER
		)
	gt1_rival_scores = data.get("gt1_rival_scores", {}).duplicate(true)
	gt1_standings.clear()
	gt1_standings.assign(data.get("gt1_standings", []))
	gt1_placement = clampi(int(data.get("gt1_placement", 0)), 0, 8)
	gt1_medal = str(data.get("gt1_medal", ""))
	gt1_standings_resolved = bool(data.get("gt1_standings_resolved", false))
	gt1_tiebreak_required = bool(data.get("gt1_tiebreak_required", false))
	prepare_month(GameState.get_month(), available_events.is_empty())
	grand_tournament_changed.emit(get_gt1_summary())


func _build_month_schedule(month: int) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	schedule.append(_build_underworld_event(month))
	if is_grand_tournament_month(month):
		schedule.append(_build_gt1_event(month))
		return schedule

	schedule.append(_build_minor_event(month, 1))
	if _has_second_official(month):
		schedule.append(_build_minor_event(month, 2))
	return schedule


func _build_underworld_event(month: int) -> Dictionary:
	return {
		"id": "underworld_m%03d" % month,
		"event_type": "underground",
		"competition": "underworld",
		"name": "Bajo Mundo",
		"scheduled_month": month,
		"scheduled_week": month,
		"scheduled_day": month,
		"format": "1v1",
		"team_size": 1,
		"opponent_count": 1,
		"series_bouts": 10,
		"reward_per_win": 60,
		"min_reputation": 0,
		"entry_fee": 0,
		"base_reward": 60,
		"difficulty": 1,
		"accepted": false,
	}


func _build_minor_event(month: int, slot: int) -> Dictionary:
	var tier := _minor_tier_for_month(month, slot)
	var prizes: Dictionary = MINOR_PRIZES[tier]
	var format := _minor_format_for_month(month, slot)
	var opponent_count := 2 if format == "1v2" else (2 if format == "2v2" else 1)
	var team_size := 2 if format == "2v2" else 1
	return {
		"id": "official_%d_m%03d" % [slot, month],
		"event_type": "official",
		"competition": "official_minor",
		"name": "Torneo oficial %s" % ["I", "II", "III"][tier - 1],
		"scheduled_month": month,
		"scheduled_week": month,
		"scheduled_day": month,
		"format": format,
		"team_size": team_size,
		"opponent_count": opponent_count,
		"series_bouts": 1,
		"tournament_tier": tier,
		"points_per_win": int(prizes.get("points", 0)),
		"champion_reward": int(prizes.get("champion", 0)),
		"eliminated_reward": int(prizes.get("eliminated", 0)),
		"champion_reputation": int(prizes.get("reputation", 0)),
		"min_reputation": 0,
		"entry_fee": 0,
		"base_reward": int(prizes.get("champion", 0)),
		"difficulty": tier,
		"requires_team_selection": team_size > 1,
		"accepted": false,
	}


func _build_gt1_event(month: int) -> Dictionary:
	var encounter: Dictionary = get_gt1_encounter(month)
	return {
		"id": "gt1_e%d_m%03d" % [int(encounter.get("encounter", 0)), month],
		"event_type": "grand_tournament",
		"competition": "grand_tournament",
		"tournament_id": GT1_ID,
		"name": "%s · Encuentro %d" % [GT1_NAME, int(encounter.get("encounter", 0))],
		"scheduled_month": month,
		"scheduled_week": month,
		"scheduled_day": month,
		"format": str(encounter.get("format", "1v1")),
		"team_size": int(encounter.get("team_size", 1)),
		"opponent_count": int(encounter.get("opponent_count", 1)),
		"series_bouts": GT1_BOUTS_PER_ENCOUNTER,
		"consecutive": bool(encounter.get("consecutive", false)),
		"same_roster": bool(encounter.get("same_roster", false)),
		"allows_beasts": bool(encounter.get("allows_beasts", false)),
		"substitutions": int(encounter.get("substitutions", 0)),
		"points_per_win": GT1_POINTS_PER_WIN,
		"description": str(encounter.get("description", "")),
		"min_reputation": 0,
		"entry_fee": 0,
		"base_reward": 0,
		"difficulty": 3,
		"requires_team_selection": int(encounter.get("team_size", 1)) > 1,
		"accepted": false,
	}


func _minor_format_for_month(month: int, slot: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = month * 7919 + slot * 104729 + 1701
	var roll := rng.randi_range(1, 100)
	if month <= 4:
		if roll <= 70:
			return "1v1"
		if roll <= 90:
			return "2v2"
		return "1v2"
	if roll <= 45:
		return "1v1"
	if roll <= 80:
		return "2v2"
	return "1v2"


func _minor_tier_for_month(month: int, slot: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = month * 1543 + slot * 6151 + 271
	return rng.randi_range(1, 3)


func _has_second_official(month: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = month * 3571 + 811
	return rng.randf() < 0.40


func _close_gt1_encounter(month: int) -> void:
	var key := str(month)
	while int(gt1_encounter_progress.get(key, 0)) < GT1_BOUTS_PER_ENCOUNTER:
		register_grand_tournament_fight_result(false, month, true)


func _finalize_gt1_standings_if_ready() -> void:
	if gt1_player_bouts < GT1_TOTAL_BOUTS or gt1_rival_scores.size() != GT1_RIVAL_COUNT:
		gt1_standings_resolved = false
		return

	var standings: Array[Dictionary] = [
		{
			"id": "player",
			"name": "Tu Ludus",
			"points": gt1_player_points,
			"wins": gt1_player_wins,
		}
	]
	for rival_id in gt1_rival_scores.keys():
		var entry: Dictionary = gt1_rival_scores[rival_id].duplicate(true)
		standings.append(entry)
	standings.sort_custom(_sort_standings)
	gt1_standings = standings

	var player_index := -1
	for index in range(gt1_standings.size()):
		if str(gt1_standings[index].get("id", "")) == "player":
			player_index = index
			break
	if player_index < 0:
		gt1_standings_resolved = false
		return

	var player_entry: Dictionary = gt1_standings[player_index]
	gt1_tiebreak_required = false
	for entry in gt1_standings:
		if str(entry.get("id", "")) == "player":
			continue
		if (
			int(entry.get("points", -1)) == int(player_entry.get("points", -2))
			and int(entry.get("wins", -1)) == int(player_entry.get("wins", -2))
		):
			gt1_tiebreak_required = true
			break

	if gt1_tiebreak_required:
		gt1_placement = 0
		gt1_medal = ""
		gt1_standings_resolved = false
		return

	gt1_placement = player_index + 1
	match gt1_placement:
		1:
			gt1_medal = "gold"
		2:
			gt1_medal = "silver"
		3:
			gt1_medal = "bronze"
		_:
			gt1_medal = ""
	gt1_standings_resolved = true


func _sort_standings(a: Dictionary, b: Dictionary) -> bool:
	var a_points := int(a.get("points", 0))
	var b_points := int(b.get("points", 0))
	if a_points != b_points:
		return a_points > b_points
	var a_wins := int(a.get("wins", 0))
	var b_wins := int(b.get("wins", 0))
	if a_wins != b_wins:
		return a_wins > b_wins
	return str(a.get("id", "")) < str(b.get("id", ""))


func _resolve_monthly_forfeit(contract: Dictionary, month: int) -> Dictionary:
	var result := contract.duplicate(true)
	result["status"] = "incomparecencia"
	result["resolved_month"] = month
	result["resolved_week"] = month
	result["resolved_day"] = month
	if str(contract.get("competition", "")) == "official_minor":
		var tier := clampi(int(contract.get("tournament_tier", 1)), 1, 3)
		var prize: Dictionary = MINOR_PRIZES[tier]
		var consolation := int(prize.get("eliminated", 0))
		GameState.denarii += consolation
		result["reward_paid"] = consolation
	else:
		result["reward_paid"] = 0
	return result


func _find_due_contract_for_fighter(fighter_id: String) -> Dictionary:
	for contract in active_contracts:
		if (
			str(contract.get("fighter_id", "")) == fighter_id
			and _scheduled_month(contract) <= GameState.get_month()
		):
			return contract
	return {}


func _calendar_matches_month(month: int) -> bool:
	if available_events.is_empty():
		return false
	for event in available_events:
		if _scheduled_month(event) != month:
			return false
	return true


func _scheduled_month(entry: Dictionary) -> int:
	return maxi(
		1,
		int(
			entry.get(
				"scheduled_month",
				entry.get("scheduled_week", entry.get("scheduled_day", GameState.get_month()))
			)
		),
	)


func _migrate_month_fields(entries: Array) -> void:
	for entry in entries:
		if not entry is Dictionary:
			continue
		var scheduled_month := _scheduled_month(entry)
		entry["scheduled_month"] = scheduled_month
		entry["scheduled_week"] = scheduled_month
		entry["scheduled_day"] = scheduled_month
		if entry.has("accepted_day") or entry.has("accepted_week") or entry.has("accepted_month"):
			var accepted_month := maxi(
				1,
				int(
					entry.get(
						"accepted_month",
						entry.get("accepted_week", entry.get("accepted_day", GameState.get_month()))
					)
				),
			)
			entry["accepted_month"] = accepted_month
			entry["accepted_week"] = accepted_month
			entry["accepted_day"] = accepted_month
		if entry.has("resolved_day") or entry.has("resolved_week") or entry.has("resolved_month"):
			var resolved_month := maxi(
				1,
				int(
					entry.get(
						"resolved_month",
						entry.get("resolved_week", entry.get("resolved_day", GameState.get_month()))
					)
				),
			)
			entry["resolved_month"] = resolved_month
			entry["resolved_week"] = resolved_month
			entry["resolved_day"] = resolved_month
