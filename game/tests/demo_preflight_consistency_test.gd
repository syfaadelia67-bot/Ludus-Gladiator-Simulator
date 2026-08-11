extends Node

const CanonicalSkillCatalog = preload("res://scripts/core/canonical_skill_catalog.gd")
const ReconciliationPolicy = preload("res://scripts/core/skill_ability_reconciliation_policy.gd")
const PersonScript = preload("res://scripts/entities/person.gd")

const EXPECTED_SKILLS := [
	"aid",
	"anchor",
	"charge",
	"closed_guard",
	"counterattack",
	"demolisher",
	"disarm",
	"execution",
	"feint",
	"immobilization",
	"interception",
	"provoke",
]
const EXPECTED_LEGACY_ABILITIES := [
	"cast_net",
	"dance_of_two_blades",
	"feint",
	"opportunity_strike",
	"precise_strike",
	"relentless_pursuit",
	"shield_charge",
	"throw_sand",
]
const EXPECTED_SPECIALIZATIONS := ["dimachaerus", "gladiator", "murmillo", "retiarius", "secutor"]
const EXPECTED_CLASS_ABILITIES := {
	"murmillo": "shield_charge",
	"secutor": "relentless_pursuit",
	"retiarius": "cast_net",
	"dimachaerus": "dance_of_two_blades",
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GladiatorProgressionManager._load_catalogs()
	TraitManager._load_catalog()
	_assert_skill_authority()
	_assert_legacy_progression_quarantine()
	_assert_trait_contracts()
	_assert_equipment_compatibility()
	_assert_migration_contracts()
	_assert_save_contract()
	print("Demo preflight consistency tests passed")
	get_tree().quit(0)


func _assert_skill_authority() -> void:
	var skills := CanonicalSkillCatalog.get_skills(DataRepository)
	assert(_sorted_ids(skills) == EXPECTED_SKILLS)
	assert(CanonicalSkillCatalog.get_general_skills(DataRepository).size() == 8)
	assert(CanonicalSkillCatalog.get_specialized_skills(DataRepository).size() == 4)
	for skill in skills:
		assert(skill.keys().size() == 3, "Canonical skills must expose identity only")
	assert(DataRepository.get_skill_mechanics_v1().is_empty())
	assert(CanonicalSkillCatalog.can_progress_skills() == false)
	assert(_sorted_ids(DataRepository.abilities) == EXPECTED_LEGACY_ABILITIES)
	var policy := ReconciliationPolicy.get_contract()
	assert(policy.get("legacy_abilities_allowed_in_combat_v1") == false)
	assert(policy.get("legacy_ability_levels_allowed_in_combat_v1") == false)
	assert(policy.get("shared_id_inherits_legacy_mechanics") == false)
	assert(CanonicalSkillCatalog.resolve_legacy_ability_as_skill("feint").is_empty())
	assert(CanonicalSkillCatalog.resolve_legacy_ability_as_skill("precise_strike").is_empty())


func _assert_legacy_progression_quarantine() -> void:
	assert(_sorted_ids(DataRepository.specializations) == EXPECTED_SPECIALIZATIONS)
	var policy := ReconciliationPolicy.get_contract()
	assert(policy.get("legacy_progression_manager_is_combat_v1_authority") == false)
	assert(policy.get("legacy_specialization_skill_mapping_allowed") == false)
	assert(policy.get("legacy_specialization_class_ability_is_canonical_skill") == false)
	for raw_entry in DataRepository.specializations:
		var entry := raw_entry as Dictionary
		var specialization_id := str(entry.get("id", ""))
		if EXPECTED_CLASS_ABILITIES.has(specialization_id):
			var class_ability := str(entry.get("class_ability", ""))
			assert(class_ability == EXPECTED_CLASS_ABILITIES[specialization_id])
			assert(CanonicalSkillCatalog.resolve_legacy_ability_as_skill(class_ability).is_empty())
	assert(GladiatorProgressionManager.canonical_specialization_id("balanced") == "gladiator")
	assert(GladiatorProgressionManager.canonical_specialization_id("thraex") == "dimachaerus")


func _assert_trait_contracts() -> void:
	assert(TraitManager.get_normal_trait_ids().size() == 16)
	assert(TraitManager.get_origin_trait_ids().is_empty())
	assert(TraitManager.get_obtainable_trait_ids().is_empty())
	_assert_mutual_incompatibility("disciplined", "impulsive")
	_assert_mutual_incompatibility("reckless", "prudent")
	assert(TraitManager.get_trait("dreamer").is_empty())


func _assert_equipment_compatibility() -> void:
	_assert_legacy_equipment_tag("shield_charge", "shield")
	_assert_legacy_equipment_tag("cast_net", "net")
	_assert_legacy_equipment_tag("dance_of_two_blades", "dual_blades")
	assert(EquipmentManager.recipes.has("retiarius_kit"))
	assert(EquipmentManager.recipes.has("dual_blades"))


func _assert_migration_contracts() -> void:
	assert(
		(
			GladiatorProgressionManager.canonical_tactical_condition("target_defending")
			== "target_guarding"
		)
	)
	assert(
		(
			GladiatorProgressionManager.canonical_tactical_condition("after_dodge_or_block")
			== "after_defense"
		)
	)
	assert(GladiatorProgressionManager.canonical_tactical_condition("unknown") == "always")


func _assert_save_contract() -> void:
	assert(SaveManager.SAVE_VERSION == 14)
	var person = (
		PersonScript
		. new(
			{
				"id": "preflight_person",
				"name": "Preflight",
				"role": "gladiator",
				"technique": 7,
				"health": 65,
				"traits": ["arena_lover", "protector", "dreamer"],
				"applied_trait_effects": ["dreamer"],
			}
		)
	)
	var serialized: Dictionary = SaveManager._serialize_person(person)
	assert(int(serialized.get("technique", 0)) == 7)
	assert(int(serialized.get("health", 0)) == 65)
	assert(serialized.get("traits", []).has("dreamer"))
	assert(serialized.get("applied_trait_effects", []).has("dreamer"))


func _assert_mutual_incompatibility(left_id: String, right_id: String) -> void:
	assert(TraitManager.get_trait(left_id).get("incompatible_with", []).has(right_id))
	assert(TraitManager.get_trait(right_id).get("incompatible_with", []).has(left_id))


func _assert_legacy_equipment_tag(ability_id: String, tag: String) -> void:
	var ability: Dictionary = GladiatorProgressionManager.abilities.get(ability_id, {})
	assert(ability.get("required_equipment_tags", []).has(tag))


func _sorted_ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_entry in entries:
		if raw_entry is Dictionary:
			result.append(str((raw_entry as Dictionary).get("id", "")))
	result.sort()
	return result
