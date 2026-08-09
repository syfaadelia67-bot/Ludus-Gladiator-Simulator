extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")
const RivalLudiDataValidatorScript = preload("res://scripts/core/rival_ludi_data_validator.gd")
const ALLOWED_ENTRY_FIELDS: Array[String] = ["rival_ludus_id", "fighter"]

var _combat_contract = CombatContractScript.new()
var _rival_ludi_validator = RivalLudiDataValidatorScript.new()


func validate_repository(repository) -> Array[String]:
	return validate_entries(repository.rival_combat_v1_snapshots)


func validate_entries(entries: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not entries is Array:
		return ["rival_combat_v1_snapshots must be an Array"]

	var canonical_rival_ids := _rival_ludi_validator.get_canonical_ids()
	var seen_fighter_keys: Dictionary = {}
	for raw_entry in entries as Array:
		if not raw_entry is Dictionary:
			errors.append("Rival Combat V1 snapshot catalog contains a non-Dictionary entry")
			continue
		var entry := raw_entry as Dictionary
		for field_name in entry.keys():
			if str(field_name) not in ALLOWED_ENTRY_FIELDS:
				errors.append(
					"Rival Combat V1 snapshot entry contains unsupported field %s" % field_name
				)

		var rival_ludus_id := str(entry.get("rival_ludus_id", ""))
		if rival_ludus_id not in canonical_rival_ids:
			errors.append("Unknown canonical rival Ludus id: %s" % rival_ludus_id)

		var fighter_value: Variant = entry.get("fighter", {})
		if not fighter_value is Dictionary:
			errors.append(
				(
					"Rival Combat V1 snapshot entry for %s must contain a fighter Dictionary"
					% rival_ludus_id
				)
			)
			continue
		var fighter := fighter_value as Dictionary
		errors.append_array(_combat_contract.validate_fighter_snapshot(fighter))
		var fighter_id := str(fighter.get("id", ""))
		if rival_ludus_id.is_empty() or fighter_id.is_empty():
			continue
		var fighter_key := "%s::%s" % [rival_ludus_id, fighter_id]
		if seen_fighter_keys.has(fighter_key):
			errors.append(
				"Duplicate rival Combat V1 fighter id %s for %s" % [fighter_id, rival_ludus_id]
			)
		else:
			seen_fighter_keys[fighter_key] = true
	return errors


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"catalog_may_be_empty_until_balance_is_frozen": true,
		"entry_identity": "rival_ludus_id + fighter.id",
		"rival_identity_source": "rival_ludi.json",
		"fighter_validation": "CombatContract.validate_fighter_snapshot",
		"generated_stats_allowed": false,
		"legacy_rival_manager_is_combat_authority": false,
		"save_version_change_required": false,
	}
