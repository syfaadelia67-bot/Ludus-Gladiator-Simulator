extends Node

const RivalCombatV1SnapshotDataValidatorScript = preload(
	"res://scripts/core/rival_combat_v1_snapshot_data_validator.gd"
)


func _ready() -> void:
	var validator = RivalCombatV1SnapshotDataValidatorScript.new()
	_test_empty_catalog_is_valid_until_balance_is_frozen(validator)
	_test_valid_entry_is_accepted(validator)
	_test_unknown_rival_is_rejected(validator)
	_test_duplicate_fighter_id_is_rejected(validator)
	_test_missing_canonical_stat_is_rejected(validator)
	_test_runtime_metadata_is_rejected(validator)
	_test_contract(validator)
	print("Rival Combat V1 snapshot data validator: OK")
	get_tree().quit(0)


func _test_empty_catalog_is_valid_until_balance_is_frozen(validator) -> void:
	assert(validator.validate_entries([]).is_empty())


func _test_valid_entry_is_accepted(validator) -> void:
	var errors: Array[String] = (
		validator
		. validate_entries(
			[
				{
					"rival_ludus_id": "cassianus",
					"fighter": _fighter("cassianus_champion", "cassianus_team"),
				}
			]
		)
	)
	assert(errors.is_empty())


func _test_unknown_rival_is_rejected(validator) -> void:
	var errors: Array[String] = (
		validator
		. validate_entries(
			[
				{
					"rival_ludus_id": "legacy_rival",
					"fighter": _fighter("legacy_champion", "legacy_team"),
				}
			]
		)
	)
	assert(errors.has("Unknown canonical rival Ludus id: legacy_rival"))


func _test_duplicate_fighter_id_is_rejected(validator) -> void:
	var errors: Array[String] = (
		validator
		. validate_entries(
			[
				{
					"rival_ludus_id": "cassianus",
					"fighter": _fighter("cassianus_champion", "cassianus_team"),
				},
				{
					"rival_ludus_id": "cassianus",
					"fighter": _fighter("cassianus_champion", "cassianus_team"),
				},
			]
		)
	)
	assert(errors.has("Duplicate rival Combat V1 fighter id cassianus_champion for cassianus"))


func _test_missing_canonical_stat_is_rejected(validator) -> void:
	var fighter := _fighter("cassianus_champion", "cassianus_team")
	(fighter.get("stats", {}) as Dictionary).erase("RES")
	var errors: Array[String] = validator.validate_entries(
		[{"rival_ludus_id": "cassianus", "fighter": fighter}]
	)
	assert(errors.has("Combat fighter cassianus_champion has unresolved stat RES"))


func _test_runtime_metadata_is_rejected(validator) -> void:
	var errors: Array[String] = (
		validator
		. validate_entries(
			[
				{
					"rival_ludus_id": "cassianus",
					"fighter": _fighter("cassianus_champion", "cassianus_team"),
					"available": true,
				}
			]
		)
	)
	assert(errors.has("Rival Combat V1 snapshot entry contains unsupported field available"))


func _test_contract(validator) -> void:
	var contract: Dictionary = validator.get_contract()
	assert(contract.get("catalog_may_be_empty_until_balance_is_frozen") == true)
	assert(contract.get("entry_identity") == "rival_ludus_id + fighter.id")
	assert(contract.get("rival_identity_source") == "rival_ludi.json")
	assert(contract.get("fighter_validation") == "CombatContract.validate_fighter_snapshot")
	assert(contract.get("generated_stats_allowed") == false)
	assert(contract.get("legacy_rival_manager_is_combat_authority") == false)
	assert(contract.get("save_version_change_required") == false)


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 5, "PV": 5},
		"stamina": 10,
		"equipment": {"power": 0, "defense": 0},
	}
