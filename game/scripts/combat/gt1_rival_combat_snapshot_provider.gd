extends RefCounted

const GT1RivalCombatSnapshotContractScript = preload(
	"res://scripts/combat/gt1_rival_combat_snapshot_contract.gd"
)
const CATALOG_PATH := "res://data/rival_combat_v1_snapshots.json"

var _snapshot_contract = GT1RivalCombatSnapshotContractScript.new()


func get_snapshot(
	rival_ludus_id: String, fighter_id: String, expected_team_id: String
) -> Dictionary:
	var catalog_result := _load_catalog()
	if catalog_result.get("status") != "ready":
		return catalog_result
	return get_snapshot_from_entries(
		catalog_result.get("entries", []) as Array,
		rival_ludus_id,
		fighter_id,
		expected_team_id,
	)


func get_snapshot_from_entries(
	entries: Array, rival_ludus_id: String, fighter_id: String, expected_team_id: String
) -> Dictionary:
	if DataRepository.get_rival_ludus(rival_ludus_id).is_empty():
		return _rejected(
			"unknown_rival_ludus",
			["Unknown canonical rival Ludus id: %s" % rival_ludus_id],
			rival_ludus_id,
			fighter_id,
			expected_team_id,
		)
	if fighter_id.is_empty():
		return _rejected(
			"rival_fighter_selection_required",
			["Rival Combat V1 snapshot lookup requires an explicit fighter id"],
			rival_ludus_id,
			fighter_id,
			expected_team_id,
		)

	var selected_validation: Dictionary = {}
	var matching_ids: Dictionary = {}
	var catalog_errors: Array[String] = []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			catalog_errors.append("Rival Combat V1 catalog contains a non-Dictionary entry")
			continue
		var entry := raw_entry as Dictionary
		if str(entry.get("rival_ludus_id", "")) != rival_ludus_id:
			continue
		var fighter_value: Variant = entry.get("fighter", {})
		if not fighter_value is Dictionary:
			catalog_errors.append(
				(
					"Rival Combat V1 catalog entry for %s must contain a fighter Dictionary"
					% rival_ludus_id
				)
			)
			continue
		var fighter := fighter_value as Dictionary
		var entry_fighter_id := str(fighter.get("id", ""))
		if not entry_fighter_id.is_empty():
			if matching_ids.has(entry_fighter_id):
				catalog_errors.append(
					(
						"Rival Combat V1 catalog contains duplicate fighter id %s for %s"
						% [entry_fighter_id, rival_ludus_id]
					)
				)
			else:
				matching_ids[entry_fighter_id] = true

		var validation := (
			_snapshot_contract
			. validate(
				rival_ludus_id,
				expected_team_id,
				fighter,
			)
		)
		if validation.get("status") != "ready":
			catalog_errors.append_array(validation.get("errors", []) as Array)
			continue
		if entry_fighter_id == fighter_id:
			selected_validation = validation.duplicate(true)

	if not catalog_errors.is_empty():
		return _rejected(
			"invalid_rival_combat_snapshot_catalog",
			catalog_errors,
			rival_ludus_id,
			fighter_id,
			expected_team_id,
		)
	if selected_validation.is_empty():
		return _rejected(
			"rival_combat_snapshot_unavailable",
			[
				(
					"No canonical Combat V1 snapshot is available for rival fighter %s in %s"
					% [fighter_id, rival_ludus_id]
				)
			],
			rival_ludus_id,
			fighter_id,
			expected_team_id,
		)

	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"rival_ludus_id": rival_ludus_id,
		"fighter_id": fighter_id,
		"expected_team_id": expected_team_id,
		"fighter_snapshot":
		(selected_validation.get("fighter_snapshot", {}) as Dictionary).duplicate(true),
		"snapshot_source": CATALOG_PATH,
		"generated_snapshot": false,
		"selection_policy": "explicit_fighter_id_required",
		"availability_policy": "not_inferred_by_provider",
		"save_version_change_required": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"catalog_path": CATALOG_PATH,
		"entry_identity": "rival_ludus_id + fighter.id",
		"fighter_validation": "gt1_rival_combat_snapshot_contract",
		"selection_policy": "explicit_fighter_id_required",
		"availability_policy": "not_inferred_by_provider",
		"generated_snapshot_allowed": false,
		"legacy_rival_manager_is_combat_authority": false,
		"save_version_change_required": false,
	}


func _load_catalog() -> Dictionary:
	if not FileAccess.file_exists(CATALOG_PATH):
		return _rejected(
			"rival_combat_snapshot_catalog_missing",
			["Canonical rival Combat V1 snapshot catalog is missing"],
			"",
			"",
			"",
		)
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return _rejected(
			"rival_combat_snapshot_catalog_unreadable",
			["Canonical rival Combat V1 snapshot catalog could not be opened"],
			"",
			"",
			"",
		)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Array:
		return _rejected(
			"invalid_rival_combat_snapshot_catalog",
			["Canonical rival Combat V1 snapshot catalog must contain a JSON Array"],
			"",
			"",
			"",
		)
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"entries": (json.data as Array).duplicate(true),
		"snapshot_source": CATALOG_PATH,
	}


func _rejected(
	reason: String,
	errors: Array,
	rival_ludus_id: String,
	fighter_id: String,
	expected_team_id: String
) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"rival_ludus_id": rival_ludus_id,
		"fighter_id": fighter_id,
		"expected_team_id": expected_team_id,
		"fighter_snapshot": {},
		"snapshot_source": CATALOG_PATH,
		"generated_snapshot": false,
		"selection_policy": "explicit_fighter_id_required",
		"availability_policy": "not_inferred_by_provider",
		"save_version_change_required": false,
	}
