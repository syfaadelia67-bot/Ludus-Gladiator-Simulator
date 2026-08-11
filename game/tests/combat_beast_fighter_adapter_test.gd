extends Node

const CombatBeastFighterAdapterScript = preload(
	"res://scripts/combat/combat_beast_fighter_adapter.gd"
)

const EXPECTED_PROFILES := {
	"boar":
	{"FUE": 7, "AGI": 5, "TEC": 6, "RES": 6, "PV": 56, "stamina": 10},
	"lion":
	{"FUE": 8, "AGI": 9, "TEC": 8, "RES": 5, "PV": 55, "stamina": 10},
	"bear":
	{"FUE": 10, "AGI": 4, "TEC": 5, "RES": 8, "PV": 68, "stamina": 10},
}


func _ready() -> void:
	DataRepository.load_all()
	var adapter = CombatBeastFighterAdapterScript.new()
	_test_catalog_audit(adapter)
	_test_canonical_snapshots(adapter)
	_test_tampered_stats_fail_closed(adapter)
	_test_tampered_restrictions_fail_closed(adapter)
	_test_invalid_identity_fails_closed(adapter)
	_test_contract(adapter)
	print("Canonical beast Combat V1 fighter adapter: OK")
	get_tree().quit(0)


func _test_catalog_audit(adapter) -> void:
	var audit: Dictionary = adapter.audit_catalog(DataRepository.beasts)
	assert(audit.get("status") == "ready")
	assert(audit.get("ready") == true)
	assert((audit.get("errors", []) as Array).is_empty())
	assert(audit.get("source") == "explicit_canonical_beast_data")
	assert(audit.get("save_version_change_required") == false)


func _test_canonical_snapshots(adapter) -> void:
	for beast_id in ["boar", "lion", "bear"]:
		var result: Dictionary = adapter.build_from_beast_id(
			beast_id, "enemy_%s" % beast_id, "beast_team"
		)
		assert(result.get("status") == "ready")
		var fighter := result.get("fighter", {}) as Dictionary
		assert(fighter.get("id") == "enemy_%s" % beast_id)
		assert(fighter.get("team") == "beast_team")
		assert(fighter.get("entity_type") == "beast")
		assert(fighter.get("beast_id") == beast_id)
		assert(fighter.get("technique_label") == "Instinto")
		assert(fighter.get("can_block") == false)
		assert(fighter.get("can_parry") == false)
		assert(fighter.get("has_skills") == false)
		assert(fighter.get("uses_equipment") == false)
		assert(fighter.get("equipment") == {"power": 0, "defense": 0})
		var expected := EXPECTED_PROFILES[beast_id] as Dictionary
		var stats := fighter.get("stats", {}) as Dictionary
		for stat_id in ["FUE", "AGI", "TEC", "RES", "PV"]:
			assert(float(stats.get(stat_id, -1.0)) == float(expected.get(stat_id, -2.0)))
		assert(float(fighter.get("stamina", -1.0)) == float(expected.get("stamina", -2.0)))


func _test_tampered_stats_fail_closed(adapter) -> void:
	var lion := _beast("lion")
	lion["AGI"] = 10
	var result: Dictionary = adapter.build_fighter(lion, "tampered_lion", "beast_team")
	assert(result.get("status") == "invalid")
	assert(_contains_error(result, "non-canonical AGI"))


func _test_tampered_restrictions_fail_closed(adapter) -> void:
	var bear := _beast("bear")
	bear["can_block"] = true
	var result: Dictionary = adapter.build_fighter(bear, "tampered_bear", "beast_team")
	assert(result.get("status") == "invalid")
	assert(_contains_error(result, "violates canonical restriction can_block"))


func _test_invalid_identity_fails_closed(adapter) -> void:
	var unknown: Dictionary = adapter.build_from_beast_id("dragon", "dragon_1", "beast_team")
	assert(unknown.get("status") == "invalid")
	assert(_contains_error(unknown, "Unknown canonical Combat V1 beast id"))
	var missing_team: Dictionary = adapter.build_from_beast_id("boar", "boar_1", "")
	assert(missing_team.get("status") == "invalid")
	assert(_contains_error(missing_team, "non-empty team_id"))


func _test_contract(adapter) -> void:
	var contract: Dictionary = adapter.get_contract()
	assert(contract.get("source") == "DataRepository.beasts")
	assert(contract.get("equipment_power") == 0)
	assert(contract.get("equipment_defense") == 0)
	assert(contract.get("block_allowed") == false)
	assert(contract.get("parry_allowed") == false)
	assert(contract.get("skills_allowed") == false)
	assert(contract.get("generated_stats_allowed") == false)
	assert(contract.get("legacy_beast_stats_allowed") == false)
	assert(contract.get("result_authority") == "combat_simulator")
	assert(contract.get("save_version_change_required") == false)


func _beast(beast_id: String) -> Dictionary:
	for raw_beast in DataRepository.beasts:
		if (
			raw_beast is Dictionary
			and str((raw_beast as Dictionary).get("id", "")) == beast_id
		):
			return (raw_beast as Dictionary).duplicate(true)
	return {}


func _contains_error(result: Dictionary, fragment: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
