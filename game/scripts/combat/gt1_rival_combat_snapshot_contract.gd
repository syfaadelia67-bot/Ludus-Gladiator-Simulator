extends RefCounted

const CombatContractScript = preload("res://scripts/combat/combat_contract.gd")

var _combat_contract = CombatContractScript.new()


func validate(
	rival_ludus_id: String, expected_team_id: String, fighter_snapshot: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	var identity := DataRepository.get_rival_ludus(rival_ludus_id)
	if identity.is_empty():
		errors.append("Unknown canonical rival Ludus id: %s" % rival_ludus_id)
	if expected_team_id.is_empty():
		errors.append("Rival Combat V1 snapshot requires a non-empty expected team id")
	if fighter_snapshot.is_empty():
		errors.append("Rival Combat V1 snapshot is required")
	else:
		errors.append_array(_combat_contract.validate_fighter_snapshot(fighter_snapshot))
		if (
			not expected_team_id.is_empty()
			and str(fighter_snapshot.get("team", "")) != expected_team_id
		):
			errors.append("Rival Combat V1 snapshot must use the declared rival team id")

	if not errors.is_empty():
		return _rejected(rival_ludus_id, expected_team_id, errors)
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"rival_ludus_id": rival_ludus_id,
		"rival_ludus_name": str(identity.get("name", rival_ludus_id)),
		"expected_team_id": expected_team_id,
		"fighter_id": str(fighter_snapshot.get("id", "")),
		"fighter_snapshot": fighter_snapshot.duplicate(true),
		"identity_source": "DataRepository.rival_ludi",
		"snapshot_source": "explicit_external_combat_v1_snapshot",
		"generated_snapshot": false,
		"storage_policy": "caller_owned_ephemeral",
		"save_version_change_required": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"identity_source": "DataRepository.rival_ludi",
		"snapshot_source": "explicit_external_combat_v1_snapshot",
		"fighter_validation": "CombatContract.validate_fighter_snapshot",
		"required_stats": CombatContractScript.CANONICAL_STAT_IDS.duplicate(),
		"requires_stamina": true,
		"requires_declared_team_match": true,
		"generated_snapshot_allowed": false,
		"legacy_rival_manager_is_combat_authority": false,
		"storage_policy": "caller_owned_ephemeral",
		"save_version_change_required": false,
	}


func _rejected(rival_ludus_id: String, expected_team_id: String, errors: Array[String]) -> Dictionary:
	return {
		"status": "rejected",
		"reason": "invalid_rival_combat_snapshot",
		"errors": errors.duplicate(),
		"rival_ludus_id": rival_ludus_id,
		"expected_team_id": expected_team_id,
		"fighter_id": "",
		"fighter_snapshot": {},
		"identity_source": "DataRepository.rival_ludi",
		"snapshot_source": "explicit_external_combat_v1_snapshot",
		"generated_snapshot": false,
		"storage_policy": "caller_owned_ephemeral",
		"save_version_change_required": false,
	}
