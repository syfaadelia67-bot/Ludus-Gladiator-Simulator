extends RefCounted

const RivalCombatV1SnapshotDataValidatorScript = preload(
	"res://scripts/core/rival_combat_v1_snapshot_data_validator.gd"
)
const RivalLudiDataValidatorScript = preload("res://scripts/core/rival_ludi_data_validator.gd")
const REQUIRED_TEAM_ID := "rival_team"
const REQUIRED_ARCHETYPES := {
	"rival_heavy":
	{
		"stats": {"FUE": 9, "AGI": 5, "TEC": 5, "RES": 5, "PV": 62},
		"stamina": 10,
	},
	"rival_agile":
	{
		"stats": {"FUE": 5, "AGI": 9, "TEC": 8, "RES": 5, "PV": 50},
		"stamina": 10,
	},
	"rival_technical":
	{
		"stats": {"FUE": 7, "AGI": 6, "TEC": 7, "RES": 5, "PV": 59},
		"stamina": 10,
	},
}

var _snapshot_validator = RivalCombatV1SnapshotDataValidatorScript.new()
var _rival_ludi_validator = RivalLudiDataValidatorScript.new()


func evaluate(entries: Array) -> Dictionary:
	var errors: Array[String] = _snapshot_validator.validate_entries(entries)
	var missing_by_ludus: Dictionary = {}
	var mismatched_profiles: Array[String] = []
	var entries_by_ludus := _entries_by_ludus(entries)
	for rival_ludus_id in _rival_ludi_validator.get_canonical_ids():
		var missing_ids: Array[String] = []
		var by_fighter_id := entries_by_ludus.get(rival_ludus_id, {}) as Dictionary
		for fighter_id in REQUIRED_ARCHETYPES.keys():
			if not by_fighter_id.has(fighter_id):
				missing_ids.append(str(fighter_id))
				continue
			var fighter := by_fighter_id[fighter_id] as Dictionary
			if not _matches_required_profile(str(fighter_id), fighter):
				mismatched_profiles.append("%s::%s" % [rival_ludus_id, fighter_id])
		if not missing_ids.is_empty():
			missing_ids.sort()
			missing_by_ludus[rival_ludus_id] = missing_ids

	var complete := (
		errors.is_empty() and missing_by_ludus.is_empty() and mismatched_profiles.is_empty()
	)
	return {
		"status": "ready" if complete else "blocked",
		"ready": complete,
		"errors": errors.duplicate(),
		"missing_by_ludus": missing_by_ludus.duplicate(true),
		"mismatched_profiles": mismatched_profiles.duplicate(),
		"required_ludi": _rival_ludi_validator.get_canonical_ids(),
		"required_fighter_ids": get_required_fighter_ids(),
		"required_team_id": REQUIRED_TEAM_ID,
		"required_entry_count":
		_rival_ludi_validator.get_canonical_ids().size() * REQUIRED_ARCHETYPES.size(),
		"actual_entry_count": entries.size(),
		"generated_stats_allowed": false,
		"save_version_change_required": false,
	}


func get_required_fighter_ids() -> Array[String]:
	var ids: Array[String] = []
	for fighter_id in REQUIRED_ARCHETYPES.keys():
		ids.append(str(fighter_id))
	ids.sort()
	return ids


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"rival_ludi": _rival_ludi_validator.get_canonical_ids(),
		"fighter_archetypes": get_required_fighter_ids(),
		"fighters_per_ludus": REQUIRED_ARCHETYPES.size(),
		"required_team_id": REQUIRED_TEAM_ID,
		"profile_source": "existing_demo_authored_combat_v1_baselines",
		"visual_archetype_count": REQUIRED_ARCHETYPES.size(),
		"generated_stats_allowed": false,
		"legacy_rival_manager_is_combat_authority": false,
		"save_version_change_required": false,
	}


func _entries_by_ludus(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var rival_ludus_id := str(entry.get("rival_ludus_id", ""))
		var fighter_value: Variant = entry.get("fighter", {})
		if rival_ludus_id.is_empty() or not fighter_value is Dictionary:
			continue
		var fighter := fighter_value as Dictionary
		var fighter_id := str(fighter.get("id", ""))
		if fighter_id.is_empty():
			continue
		if not result.has(rival_ludus_id):
			result[rival_ludus_id] = {}
		(result[rival_ludus_id] as Dictionary)[fighter_id] = fighter.duplicate(true)
	return result


func _matches_required_profile(fighter_id: String, fighter: Dictionary) -> bool:
	if not REQUIRED_ARCHETYPES.has(fighter_id):
		return false
	var expected := REQUIRED_ARCHETYPES[fighter_id] as Dictionary
	if str(fighter.get("team", "")) != REQUIRED_TEAM_ID:
		return false
	var actual_stats_value: Variant = fighter.get("stats", {})
	var expected_stats_value: Variant = expected.get("stats", {})
	if not actual_stats_value is Dictionary or not expected_stats_value is Dictionary:
		return false
	var actual_stats := actual_stats_value as Dictionary
	var expected_stats := expected_stats_value as Dictionary
	for stat_id in expected_stats.keys():
		if not actual_stats.has(stat_id):
			return false
		if float(actual_stats[stat_id]) != float(expected_stats[stat_id]):
			return false
	return float(fighter.get("stamina", -1.0)) == float(expected.get("stamina", -2.0))
