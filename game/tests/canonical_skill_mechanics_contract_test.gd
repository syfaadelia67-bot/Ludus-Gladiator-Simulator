extends Node

const CanonicalSkillMechanicsContractScript = preload(
	"res://scripts/core/canonical_skill_mechanics_contract.gd"
)


func _ready() -> void:
	DataRepository.load_all()
	var contract = CanonicalSkillMechanicsContractScript.new()
	_assert_production_source_is_fail_closed(contract)
	_assert_partial_catalog_cannot_fake_readiness(contract)
	_assert_legacy_mechanics_are_rejected(contract)
	_assert_runtime_cannot_precede_frozen_design(contract)
	_assert_contract_boundary(contract.get_contract())
	print("Canonical Combat V1 skill mechanics boundary: OK")
	get_tree().quit(0)


func _assert_production_source_is_fail_closed(contract) -> void:
	assert(DataRepository.get_skill_mechanics_v1().is_empty())
	var readiness: Dictionary = contract.evaluate(
		DataRepository.get_skills(), DataRepository.get_skill_mechanics_v1(), false
	)
	assert(readiness.get("status") == "blocked")
	assert(readiness.get("ready") == false)
	assert(readiness.get("identity_ready") == true)
	assert(readiness.get("mechanics_ready") == false)
	assert(readiness.get("progression_ready") == false)
	assert(readiness.get("design_ready") == false)
	assert(readiness.get("runtime_resolver_ready") == false)
	assert((readiness.get("missing_mechanics_ids", []) as Array).size() == 12)
	assert((readiness.get("missing_progression_ids", []) as Array).size() == 12)
	assert(readiness.get("legacy_ability_import_allowed") == false)
	assert(readiness.get("invent_mechanics_allowed") == false)


func _assert_partial_catalog_cannot_fake_readiness(contract) -> void:
	var readiness: Dictionary = contract.evaluate(
		DataRepository.get_skills(), [_fixture_entry("counterattack")], true
	)
	assert(readiness.get("ready") == false)
	assert(readiness.get("mechanics_ready") == false)
	assert((readiness.get("missing_mechanics_ids", []) as Array).size() == 11)


func _assert_legacy_mechanics_are_rejected(contract) -> void:
	var entry := _fixture_entry("feint")
	var mechanics := entry.get("mechanics", {}) as Dictionary
	mechanics["cost"] = {"energy_cost": 10}
	mechanics["effects"] = {"primary_stats": ["FUE"], "intelligence": 1}
	entry["mechanics"] = mechanics
	var readiness: Dictionary = contract.evaluate(DataRepository.get_skills(), [entry], true)
	var errors := readiness.get("errors", []) as Array
	assert(_contains(errors, "energy_cost"))
	assert(_contains(errors, "primary_stats"))
	assert(_contains(errors, "intelligence"))
	assert(readiness.get("ready") == false)


func _assert_runtime_cannot_precede_frozen_design(contract) -> void:
	var entries: Array = []
	for raw_skill in DataRepository.get_skills():
		entries.append(_fixture_entry(str((raw_skill as Dictionary).get("id", ""))))
	var design_only: Dictionary = contract.evaluate(DataRepository.get_skills(), entries, false)
	assert(design_only.get("design_ready") == true)
	assert(design_only.get("ready") == false)
	var runtime_ready: Dictionary = contract.evaluate(DataRepository.get_skills(), entries, true)
	assert(runtime_ready.get("design_ready") == true)
	assert(runtime_ready.get("ready") == true)


func _assert_contract_boundary(boundary: Dictionary) -> void:
	assert(boundary.get("canonical_identity_source") == "DataRepository.skills")
	assert(boundary.get("canonical_mechanics_source") == "DataRepository.skill_mechanics_v1")
	assert(boundary.get("legacy_ability_import_allowed") == false)
	assert(boundary.get("legacy_progression_import_allowed") == false)
	assert(boundary.get("invent_mechanics_allowed") == false)
	assert(boundary.get("runtime_requires_frozen_design") == true)
	assert(boundary.get("save_version_change_required") == false)


func _fixture_entry(skill_id: String) -> Dictionary:
	return {
		"id": skill_id,
		"status": "frozen",
		"source": "approved_combat_v1_design",
		"mechanics":
		{
			"action_mapping": {"fixture": true},
			"cost": {"fixture": true},
			"timing": {"fixture": true},
			"targets": {"fixture": true},
			"equipment_requirements": [],
			"effects": {"fixture": true},
		},
		"progression": {"status": "frozen", "fixture": true},
	}


func _contains(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false
