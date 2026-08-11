extends Node

const GT1RivalRosterReadinessContractScript = preload(
	"res://scripts/combat/gt1_rival_roster_readiness_contract.gd"
)


func run() -> void:
	DataRepository.load_all()
	var contract = GT1RivalRosterReadinessContractScript.new()
	_test_canonical_catalog_is_complete(contract)
	_test_missing_single_archetype_blocks_readiness(contract)
	_test_profile_drift_blocks_readiness(contract)
	_test_contract_is_frozen(contract)
	print("GT I rival roster readiness contract: OK")


func _test_canonical_catalog_is_complete(contract) -> void:
	var entries := DataRepository.get_rival_combat_v1_snapshots()
	var result: Dictionary = contract.evaluate(entries)
	assert(result.get("status") == "ready")
	assert(result.get("ready") == true)
	assert(int(result.get("required_entry_count", 0)) == 21)
	assert(int(result.get("actual_entry_count", 0)) == 21)
	assert((result.get("missing_by_ludus", {}) as Dictionary).is_empty())
	assert((result.get("mismatched_profiles", []) as Array).is_empty())
	assert((result.get("errors", []) as Array).is_empty())
	assert(result.get("required_fighter_ids") == ["rival_agile", "rival_heavy", "rival_technical"])
	for raw_entry in entries:
		var fighter := (raw_entry as Dictionary).get("fighter", {}) as Dictionary
		assert(fighter.get("team") == "rival_team")
		assert(float(fighter.get("stamina", 0.0)) == 10.0)
		assert(not fighter.has("equipment"))
		assert(not fighter.has("skills"))
		assert(not fighter.has("traits"))
		assert(not fighter.has("specialization"))


func _test_missing_single_archetype_blocks_readiness(contract) -> void:
	var entries := DataRepository.get_rival_combat_v1_snapshots()
	for index in range(entries.size() - 1, -1, -1):
		var entry := entries[index] as Dictionary
		var fighter := entry.get("fighter", {}) as Dictionary
		if entry.get("rival_ludus_id") == "cassianus" and fighter.get("id") == "rival_agile":
			entries.remove_at(index)
			break
	var result: Dictionary = contract.evaluate(entries)
	assert(result.get("status") == "blocked")
	assert(result.get("ready") == false)
	var missing := result.get("missing_by_ludus", {}) as Dictionary
	assert((missing.get("cassianus", []) as Array).has("rival_agile"))


func _test_profile_drift_blocks_readiness(contract) -> void:
	var entries := DataRepository.get_rival_combat_v1_snapshots()
	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		var fighter := entry.get("fighter", {}) as Dictionary
		if entry.get("rival_ludus_id") == "varro" and fighter.get("id") == "rival_heavy":
			(fighter.get("stats", {}) as Dictionary)["FUE"] = 10
			break
	var result: Dictionary = contract.evaluate(entries)
	assert(result.get("status") == "blocked")
	assert((result.get("mismatched_profiles", []) as Array).has("varro::rival_heavy"))


func _test_contract_is_frozen(contract) -> void:
	var snapshot: Dictionary = contract.get_contract()
	assert(snapshot.get("fighters_per_ludus") == 3)
	assert(snapshot.get("required_team_id") == "rival_team")
	assert(snapshot.get("visual_archetype_count") == 3)
	assert(snapshot.get("generated_stats_allowed") == false)
	assert(snapshot.get("legacy_rival_manager_is_combat_authority") == false)
	assert(snapshot.get("save_version_change_required") == false)
