extends RefCounted

const PODIUM_SIZE := 3


func evaluate(
	standings: Array,
	non_podium_tiebreak_data: Dictionary = {},
	player_id: String = "player"
) -> Dictionary:
	var validation_errors := _validate_standings(standings, player_id)
	if not validation_errors.is_empty():
		return _rejected("invalid_standings", validation_errors)

	var player_entry := _find_entry(standings, player_id)
	var tied_entries := _find_tied_entries(standings, player_entry)
	var strictly_ahead := _count_strictly_ahead(standings, player_entry)
	var first_tied_position := strictly_ahead + 1
	var last_tied_position := first_tied_position + tied_entries.size() - 1
	var tied_rival_ids := _rival_ids(tied_entries, player_id)

	if tied_rival_ids.is_empty():
		return _resolved(first_tied_position, "points_then_wins", [], false)

	var affects_podium := first_tied_position <= PODIUM_SIZE
	if affects_podium:
		return {
			"status": "podium_combat_required",
			"reason": "podium_tie",
			"errors": [],
			"placement": 0,
			"medal": "",
			"tied_rival_ids": tied_rival_ids.duplicate(),
			"first_tied_position": first_tied_position,
			"last_tied_position": last_tied_position,
			"requires_combat_tiebreak": true,
			"requires_non_podium_data": false,
			"resolution_source": "tournament_characteristic_combat",
		}

	var non_podium_resolution := _resolve_non_podium_tie(
		tied_rival_ids,
		non_podium_tiebreak_data,
		player_id,
	)
	if non_podium_resolution.get("status") != "resolved":
		return {
			"status": "non_podium_data_required",
			"reason": "missing_non_podium_tiebreak_data",
			"errors": (non_podium_resolution.get("errors", []) as Array).duplicate(),
			"placement": 0,
			"medal": "",
			"tied_rival_ids": tied_rival_ids.duplicate(),
			"first_tied_position": first_tied_position,
			"last_tied_position": last_tied_position,
			"requires_combat_tiebreak": false,
			"requires_non_podium_data": true,
			"resolution_source": "head_to_head_then_prior_season_position",
		}

	var rivals_ahead := int(non_podium_resolution.get("rivals_ahead_of_player", 0))
	return _resolved(
		first_tied_position + rivals_ahead,
		"head_to_head_then_prior_season_position",
		tied_rival_ids,
		true,
	)


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"primary_ranking": ["points", "wins"],
		"podium_tie": "tournament_characteristic_combat",
		"non_podium_tie": ["head_to_head", "prior_season_position"],
		"missing_non_podium_data": "pending",
		"alphabetical_fallback_allowed": false,
		"random_fallback_allowed": false,
		"podium_size": PODIUM_SIZE,
	}


func _resolve_non_podium_tie(
	tied_rival_ids: Array[String],
	tiebreak_data: Dictionary,
	player_id: String
) -> Dictionary:
	var errors: Array[String] = []
	var rivals_ahead := 0
	for rival_id in tied_rival_ids:
		var raw_data: Variant = tiebreak_data.get(rival_id, null)
		if not raw_data is Dictionary:
			errors.append("Missing non-podium tiebreak data for %s" % rival_id)
			continue
		var data := raw_data as Dictionary
		var comparison := _compare_player_to_rival(data, player_id, rival_id)
		if comparison == 0:
			errors.append("Incomplete non-podium tiebreak data for %s" % rival_id)
			continue
		if comparison < 0:
			rivals_ahead += 1
	if not errors.is_empty():
		return {
			"status": "pending",
			"errors": errors,
			"rivals_ahead_of_player": 0,
		}
	return {
		"status": "resolved",
		"errors": [],
		"rivals_ahead_of_player": rivals_ahead,
	}


func _compare_player_to_rival(data: Dictionary, player_id: String, rival_id: String) -> int:
	var head_to_head_winner := str(data.get("head_to_head_winner_id", ""))
	if head_to_head_winner == player_id:
		return 1
	if head_to_head_winner == rival_id:
		return -1
	if not head_to_head_winner.is_empty():
		return 0

	var player_prior_position := int(data.get("player_prior_season_position", 0))
	var rival_prior_position := int(data.get("rival_prior_season_position", 0))
	if player_prior_position <= 0 or rival_prior_position <= 0:
		return 0
	if player_prior_position == rival_prior_position:
		return 0
	return 1 if player_prior_position < rival_prior_position else -1


func _validate_standings(standings: Array, player_id: String) -> Array[String]:
	var errors: Array[String] = []
	if player_id.is_empty():
		errors.append("player_id is required")
	var seen: Dictionary = {}
	var player_count := 0
	for raw_entry in standings:
		if not raw_entry is Dictionary:
			errors.append("Standings entries must be Dictionaries")
			continue
		var entry := raw_entry as Dictionary
		var entry_id := str(entry.get("id", ""))
		if entry_id.is_empty():
			errors.append("Standings entry id is required")
			continue
		if seen.has(entry_id):
			errors.append("Duplicate standings id: %s" % entry_id)
		seen[entry_id] = true
		if entry_id == player_id:
			player_count += 1
		if int(entry.get("points", -1)) < 0:
			errors.append("Standings points must be non-negative for %s" % entry_id)
		if int(entry.get("wins", -1)) < 0:
			errors.append("Standings wins must be non-negative for %s" % entry_id)
	if player_count != 1:
		errors.append("Standings must contain exactly one player entry")
	return errors


func _find_entry(standings: Array, entry_id: String) -> Dictionary:
	for raw_entry in standings:
		var entry := raw_entry as Dictionary
		if str(entry.get("id", "")) == entry_id:
			return entry
	return {}


func _find_tied_entries(standings: Array, player_entry: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var player_points := int(player_entry.get("points", 0))
	var player_wins := int(player_entry.get("wins", 0))
	for raw_entry in standings:
		var entry := raw_entry as Dictionary
		if (
			int(entry.get("points", -1)) == player_points
			and int(entry.get("wins", -1)) == player_wins
		):
			result.append(entry)
	return result


func _count_strictly_ahead(standings: Array, player_entry: Dictionary) -> int:
	var count := 0
	var player_points := int(player_entry.get("points", 0))
	var player_wins := int(player_entry.get("wins", 0))
	for raw_entry in standings:
		var entry := raw_entry as Dictionary
		if str(entry.get("id", "")) == str(player_entry.get("id", "")):
			continue
		var points := int(entry.get("points", 0))
		var wins := int(entry.get("wins", 0))
		if points > player_points or (points == player_points and wins > player_wins):
			count += 1
	return count


func _rival_ids(entries: Array[Dictionary], player_id: String) -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		var entry_id := str(entry.get("id", ""))
		if entry_id != player_id:
			ids.append(entry_id)
	ids.sort()
	return ids


func _resolved(
	placement: int,
	resolution_source: String,
	tied_rival_ids: Array[String],
	used_non_podium_tiebreak: bool
) -> Dictionary:
	return {
		"status": "resolved",
		"reason": "",
		"errors": [],
		"placement": placement,
		"medal": _medal_for_placement(placement),
		"tied_rival_ids": tied_rival_ids.duplicate(),
		"first_tied_position": placement,
		"last_tied_position": placement,
		"requires_combat_tiebreak": false,
		"requires_non_podium_data": false,
		"used_non_podium_tiebreak": used_non_podium_tiebreak,
		"resolution_source": resolution_source,
	}


func _medal_for_placement(placement: int) -> String:
	match placement:
		1:
			return "gold"
		2:
			return "silver"
		3:
			return "bronze"
		_:
			return ""


func _rejected(reason: String, errors: Array[String]) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"placement": 0,
		"medal": "",
		"tied_rival_ids": [],
		"first_tied_position": 0,
		"last_tied_position": 0,
		"requires_combat_tiebreak": false,
		"requires_non_podium_data": false,
		"resolution_source": "",
	}
