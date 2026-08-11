extends Node

const GT1ChampionshipTiebreakCatalogRuntimeScript = preload(
	"res://scripts/combat/gt1_championship_tiebreak_catalog_runtime.gd"
)
const GT1RivalCombatSnapshotProviderScript = preload(
	"res://scripts/combat/gt1_rival_combat_snapshot_provider.gd"
)


func _ready() -> void:
	_test_empty_entry_source_fails_closed()
	_test_canonical_catalog_is_populated_and_resolvable()
	_test_explicit_entry_is_validated_and_copied()
	_test_explicit_fighter_selection_is_required()
	_test_team_mismatch_is_rejected()
	_test_unknown_rival_is_rejected()
	_test_catalog_runtime_contract()
	print("GT I rival Combat V1 snapshot provider: OK")
	get_tree().quit(0)


func _test_empty_entry_source_fails_closed() -> void:
	var provider = GT1RivalCombatSnapshotProviderScript.new()
	var result := provider.get_snapshot_from_entries([], "cassianus", "rival_heavy", "rival_team")
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "rival_combat_snapshot_unavailable")
	assert(result.get("generated_snapshot") == false)
	assert(result.get("snapshot_source") == "res://data/rival_combat_v1_snapshots.json")


func _test_canonical_catalog_is_populated_and_resolvable() -> void:
	DataRepository.load_all()
	var provider = GT1RivalCombatSnapshotProviderScript.new()
	var result := provider.get_snapshot("cassianus", "rival_heavy", "rival_team")
	assert(result.get("status") == "ready")
	assert(result.get("fighter_id") == "rival_heavy")
	assert(result.get("rival_ludus_id") == "cassianus")
	var fighter := result.get("fighter_snapshot", {}) as Dictionary
	assert(fighter.get("team") == "rival_team")
	assert(fighter.get("stats") == {"FUE": 9, "AGI": 5, "TEC": 5, "RES": 5, "PV": 62})
	assert(float(fighter.get("stamina", 0.0)) == 10.0)


func _test_explicit_entry_is_validated_and_copied() -> void:
	var provider = GT1RivalCombatSnapshotProviderScript.new()
	var entries := [
		{
			"rival_ludus_id": "cassianus",
			"fighter": _fighter("rival_glad", "beta"),
		}
	]
	var result := (
		provider
		. get_snapshot_from_entries(
			entries,
			"cassianus",
			"rival_glad",
			"beta",
		)
	)
	assert(result.get("status") == "ready")
	assert(result.get("fighter_id") == "rival_glad")
	assert(result.get("selection_policy") == "explicit_fighter_id_required")
	assert(result.get("availability_policy") == "not_inferred_by_provider")
	assert(result.get("generated_snapshot") == false)

	var source_fighter := (entries[0] as Dictionary).get("fighter", {}) as Dictionary
	var source_stats := source_fighter.get("stats", {}) as Dictionary
	source_stats["PV"] = 999
	var frozen_fighter := result.get("fighter_snapshot", {}) as Dictionary
	var frozen_stats := frozen_fighter.get("stats", {}) as Dictionary
	assert(int(frozen_stats.get("PV", 0)) == 5)


func _test_explicit_fighter_selection_is_required() -> void:
	var provider = GT1RivalCombatSnapshotProviderScript.new()
	var result := provider.get_snapshot_from_entries([], "cassianus", "", "beta")
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "rival_fighter_selection_required")


func _test_team_mismatch_is_rejected() -> void:
	var provider = GT1RivalCombatSnapshotProviderScript.new()
	var result := (
		provider
		. get_snapshot_from_entries(
			[
				{
					"rival_ludus_id": "cassianus",
					"fighter": _fighter("rival_glad", "gamma"),
				}
			],
			"cassianus",
			"rival_glad",
			"beta",
		)
	)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "invalid_rival_combat_snapshot_catalog")
	assert(
		(result.get("errors", []) as Array).has(
			"Rival Combat V1 snapshot must use the declared rival team id"
		)
	)


func _test_unknown_rival_is_rejected() -> void:
	var provider = GT1RivalCombatSnapshotProviderScript.new()
	var result := provider.get_snapshot_from_entries([], "legacy_rival", "fighter", "beta")
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "unknown_rival_ludus")


func _test_catalog_runtime_contract() -> void:
	var runtime = GT1ChampionshipTiebreakCatalogRuntimeScript.new()
	var contract := runtime.get_contract()
	assert(contract.get("supported_tie") == "two_ludi_tied_first_at_27_points")
	assert(contract.get("format") == "1v1")
	assert(contract.get("rival_source") == "res://data/rival_combat_v1_snapshots.json")
	assert(contract.get("rival_provider") == "gt1_rival_combat_snapshot_provider")
	assert(contract.get("rival_selection_policy") == "explicit_fighter_id_required")
	assert(contract.get("rival_availability_policy") == "not_inferred_by_provider")
	assert(contract.get("rival_generation_allowed") == false)
	assert(contract.get("legacy_rival_manager_is_combat_authority") == false)
	assert(contract.get("combat_result_authority") == "CombatSimulator")
	assert(contract.get("standings_authority") == "TournamentManager")
	assert(contract.get("save_version_change_required") == false)


func _fighter(fighter_id: String, team_id: String) -> Dictionary:
	return {
		"id": fighter_id,
		"team": team_id,
		"stats": {"FUE": 10, "AGI": 10, "TEC": 10, "RES": 5, "PV": 5},
		"stamina": 10,
		"equipment": {"power": 0, "defense": 0},
	}
