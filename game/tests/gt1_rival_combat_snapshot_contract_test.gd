extends Node

const GT1RivalCombatSnapshotContractScript = preload(
	"res://scripts/combat/gt1_rival_combat_snapshot_contract.gd"
)


func _ready() -> void:
	DataRepository.load_all()
	var contract = GT1RivalCombatSnapshotContractScript.new()
	_test_valid_explicit_snapshot(contract)
	_test_unknown_rival_is_rejected(contract)
	_test_team_mismatch_is_rejected(contract)
	_test_unresolved_canonical_stat_is_rejected(contract)
	_test_empty_snapshot_is_rejected(contract)
	_test_contract(contract)
	print("GT I rival Combat V1 snapshot contract: OK")
	get_tree().quit(0)


func _test_valid_explicit_snapshot(contract) -> void:
	var source := _fighter("beta")
	var result: Dictionary = contract.validate("cassianus", "beta", source)
	assert(result.get("status") == "ready")
	assert(result.get("rival_ludus_id") == "cassianus")
	assert(result.get("rival_ludus_name") == "Ludus Cassianus")
	assert(result.get("expected_team_id") == "beta")
	assert(result.get("fighter_id") == "cassianus_champion")
	assert(result.get("identity_source") == "DataRepository.rival_ludi")
	assert(result.get("snapshot_source") == "explicit_external_combat_v1_snapshot")
	assert(result.get("generated_snapshot") == false)
	assert(result.get("storage_policy") == "caller_owned_ephemeral")
	assert(result.get("save_version_change_required") == false)

	source["stats"]["FUE"] = 99
	var frozen := result.get("fighter_snapshot", {}) as Dictionary
	assert(int((frozen.get("stats", {}) as Dictionary).get("FUE", 0)) == 10)


func _test_unknown_rival_is_rejected(contract) -> void:
	var result: Dictionary = (
		contract.validate("legacy_rival", "beta", _fighter("beta"))
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "invalid_rival_combat_snapshot")
	assert(
		(result.get("errors", []) as Array).has(
			"Unknown canonical rival Ludus id: legacy_rival"
		)
	)
	assert(result.get("generated_snapshot") == false)


func _test_team_mismatch_is_rejected(contract) -> void:
	var result: Dictionary = contract.validate("cassianus", "beta", _fighter("gamma"))
	assert(result.get("status") == "rejected")
	assert(
		(result.get("errors", []) as Array).has(
			"Rival Combat V1 snapshot must use the declared rival team id"
		)
	)


func _test_unresolved_canonical_stat_is_rejected(contract) -> void:
	var fighter := _fighter("beta")
	(fighter.get("stats", {}) as Dictionary).erase("RES")
	var result: Dictionary = contract.validate("cassianus", "beta", fighter)
	assert(result.get("status") == "rejected")
	assert(
		(result.get("errors", []) as Array).has(
			"Combat fighter cassianus_champion has unresolved stat RES"
		)
	)


func _test_empty_snapshot_is_rejected(contract) -> void:
	var result: Dictionary = contract.validate("cassianus", "beta", {})
	assert(result.get("status") == "rejected")
	assert((result.get("errors", []) as Array).has("Rival Combat V1 snapshot is required"))


func _test_contract(contract) -> void:
	var frozen: Dictionary = contract.get_contract()
	assert(frozen.get("identity_source") == "DataRepository.rival_ludi")
	assert(frozen.get("snapshot_source") == "explicit_external_combat_v1_snapshot")
	assert(frozen.get("fighter_validation") == "CombatContract.validate_fighter_snapshot")
	assert(frozen.get("required_stats") == ["FUE", "AGI", "TEC", "RES", "PV"])
	assert(frozen.get("requires_stamina") == true)
	assert(frozen.get("requires_declared_team_match") == true)
	assert(frozen.get("generated_snapshot_allowed") == false)
	assert(frozen.get("legacy_rival_manager_is_combat_authority") == false)
	assert(frozen.get("storage_policy") == "caller_owned_ephemeral")
	assert(frozen.get("save_version_change_required") == false)


func _fighter(team_id: String) -> Dictionary:
	return {
		"id": "cassianus_champion",
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 11, "TEC": 12, "RES": 13, "PV": 14},
		"stamina": 15,
		"equipment": {"power": 2, "defense": 1},
	}
