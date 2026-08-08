extends RefCounted

const ACTION_IDS: Array[String] = [
	"light",
	"heavy",
	"block",
	"parry",
	"dodge",
	"reposition",
]
const FORMAT_TEAM_SIZES := {
	"1v1": [1, 1],
	"2v2": [2, 2],
	"1v2": [1, 2],
}
const CANONICAL_STAT_IDS: Array[String] = ["FUE", "AGI", "TEC", "RES", "PV"]


func is_action_id_valid(action_id: String) -> bool:
	return ACTION_IDS.has(action_id)


func validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var format_id := str(state.get("format", ""))
	if not FORMAT_TEAM_SIZES.has(format_id):
		errors.append("Unsupported combat format: %s" % format_id)
		return errors

	var fighters_value: Variant = state.get("fighters", [])
	if not fighters_value is Array:
		errors.append("Combat state fighters must be an Array")
		return errors
	var fighters: Array = fighters_value as Array
	_validate_fighters(fighters, errors)
	_validate_team_sizes(format_id, fighters, errors)
	return errors


func _validate_fighters(fighters: Array, errors: Array[String]) -> void:
	var seen_ids: Dictionary = {}
	for raw_fighter in fighters:
		if not raw_fighter is Dictionary:
			errors.append("Combat state contains a non-Dictionary fighter")
			continue
		var fighter: Dictionary = raw_fighter
		var fighter_id := str(fighter.get("id", ""))
		if fighter_id.is_empty():
			errors.append("Combat fighter is missing id")
		elif seen_ids.has(fighter_id):
			errors.append("Combat state contains duplicate fighter id: %s" % fighter_id)
		else:
			seen_ids[fighter_id] = true

		var team_id := str(fighter.get("team", ""))
		if team_id.is_empty():
			errors.append("Combat fighter %s is missing team" % fighter_id)

		var stats_value: Variant = fighter.get("stats", {})
		if not stats_value is Dictionary:
			errors.append("Combat fighter %s stats must be a Dictionary" % fighter_id)
			continue
		var stats: Dictionary = stats_value
		for stat_id in CANONICAL_STAT_IDS:
			if not stats.has(stat_id) or stats[stat_id] == null:
				errors.append("Combat fighter %s has unresolved stat %s" % [fighter_id, stat_id])
			elif not _is_numeric(stats[stat_id]):
				errors.append("Combat fighter %s stat %s must be numeric" % [fighter_id, stat_id])

		if not fighter.has("stamina"):
			errors.append("Combat fighter %s is missing stamina" % fighter_id)
		elif not _is_numeric(fighter["stamina"]):
			errors.append("Combat fighter %s stamina must be numeric" % fighter_id)


func _validate_team_sizes(format_id: String, fighters: Array, errors: Array[String]) -> void:
	var counts: Dictionary = {}
	for raw_fighter in fighters:
		if not raw_fighter is Dictionary:
			continue
		var team_id := str((raw_fighter as Dictionary).get("team", ""))
		if team_id.is_empty():
			continue
		counts[team_id] = int(counts.get(team_id, 0)) + 1
	if counts.size() != 2:
		errors.append("Combat format %s requires exactly two teams" % format_id)
		return

	var actual_sizes: Array[int] = []
	for count_value in counts.values():
		actual_sizes.append(int(count_value))
	actual_sizes.sort()
	var required_sizes: Array = (FORMAT_TEAM_SIZES[format_id] as Array).duplicate()
	required_sizes.sort()
	if actual_sizes != required_sizes:
		errors.append(
			"Combat format %s requires team sizes %s" % [format_id, FORMAT_TEAM_SIZES[format_id]]
		)


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float
