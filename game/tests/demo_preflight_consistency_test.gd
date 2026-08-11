extends Node

const CanonicalSkillCatalog = preload("res://scripts/core/canonical_skill_catalog.gd")
const ReconciliationPolicy = preload("res://scripts/core/skill_ability_reconciliation_policy.gd")

const EXPECTED_SKILLS := [
	"counterattack",
	"charge",
	"closed_guard",
	"demolisher",
	"feint",
	"provoke",
	"execution",
	"aid",
	"anchor",
	"disarm",
	"immobilization",
	"interception",
]
const EXPECTED_LEGACY_ABILITIES := [
	"precise_strike",
	"feint",
	"opportunity_strike",
	"throw_sand",
	"shield_charge",
	"relentless_pursuit",
	"cast_net",
	"dance_of_two_blades",
]
const EXPECTED_SPECIALIZATIONS := ["gladiator", "murmillo", "secutor", "retiarius", "dimachaerus"]
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

	_assert_skill_catalog()
	_assert_legacy_ability_quarantine()
	_assert_specialization_catalog()
	_assert_trait_catalog()
	_assert_equipment_contracts()
	_assert_migration_contracts()
	_assert_save_contract()

	print("Demo preflight consistency tests passed")
	get_tree().quit(0)


func _assert_skill_catalog() -> void:
	var skills := CanonicalSkillCatalog.get_skills(DataRepository)
	assert(skills.size() == 12, "Combat V1 must expose exactly twelve canonical skills")
	var found: Array[String] = []
	for entry in skills:
		assert(entry.keys().size() == 3, "Canonical skill snapshots must contain identity only")
		found.append(str(entry.get("id", "")))
	found.sort()
	var expected := EXPECTED_SKILLS.duplicate()
	expected.sort()
	assert(found == expected, "Canonical Combat V1 skill ids must match the frozen twelve-skill catalog")
	assert(CanonicalSkillCatalog.get_general_skills(DataRepository).size() == 8)
	assert(CanonicalSkillCatalog.get_specialized_skills(DataRepository).size() == 4)
	assert(
		DataRepository.get_skill_mechanics_v1().is_empty(),
		"Combat V1 skill mechanics source must remain empty until approved design is frozen",
	)
	assert(
		CanonicalSkillCatalog.can_progress_skills() == false,
		"Canonical skill progression must fail closed while mechanics/progression are pending",
	)


func _assert_legacy_ability_quarantine() -> void:
	assert(
		DataRepository.abilities.size() == 8,
		"Eight legacy abilities must remain available only for compatibility",
	)
	var found: Array[String] = []
	for raw_entry in DataRepository.abilities:
		assert(raw_entry is Dictionary, "Every legacy ability entry must be a dictionary")
		found.append(str((raw_entry as Dictionary).get("id", "")))
	found.sort()
	var expected := EXPECTED_LEGACY_ABILITIES.duplicate()
	expected.sort()
	assert(found == expected, "Legacy ability compatibility ids must remain stable")
	assert(ReconciliationPolicy.get_contract().get("legacy_abilities_allowed_in_combat_v1") == false)
	assert(
		CanonicalSkillCatalog.resolve_legacy_ability_as_skill("feint").is_empty(),
		"Shared id Finta must not inherit legacy mechanics",
	)
	assert(
		CanonicalSkillCatalog.resolve_legacy_ability_as_skill("precise_strike").is_empty(),
		"Legacy-only abilities must never become Combat V1 skills",
	)


func _assert_specialization_catalog() -> void:
	assert(
		DataRepository.specializations.size() == 5,
		"Legacy progression compatibility must preserve the generic class plus four specializations",
	)
	var found: Array[String] = []
	for raw_entry in DataRepository.specializations:
		assert(raw_entry is Dictionary, "Every specialization entry must be a dictionary")
		var entry: Dictionary = raw_entry
		var specialization_id := str(entry.get("id", ""))
		found.append(specialization_id)
		var growth: Dictionary = entry.get("growth_per_level", {})
		var budget := (
			int(growth.get("strength", 0))
			+ int(growth.get("agility", 0))
			+ int(growth.get("endurance", 0))
			+ int(growth.get("intelligence", 0))
			+ int(growth.get("technique", 0))
		)
		budget += int(growth.get("health", 0)) / 5
		assert(
			budget == 12,
			"%s legacy progression growth must preserve its compatibility budget" % specialization_id,
		)
		if EXPECTED_CLASS_ABILITIES.has(specialization_id):
			var class_ability := str(entry.get("class_ability", ""))
			assert(
				class_ability == EXPECTED_CLASS_ABILITIES[specialization_id],
				"%s legacy class ability compatibility link must stay stable" % specialization_id,
			)
			assert(
				CanonicalSkillCatalog.resolve_legacy_ability_as_skill(class_ability).is_empty(),
				"Legacy specialization class abilities must not become canonical skills",
			)
	found.sort()
	var expected := EXPECTED_SPECIALIZATIONS.duplicate()
	expected.sort()
	assert(found == expected, "Legacy specialization compatibility ids must remain stable")
	assert(
		ReconciliationPolicy.get_contract().get(
			"legacy_specialization_class_ability_is_canonical_skill"
		)
		== false
	)
	assert(
		ReconciliationPolicy.get_contract().get("legacy_progression_manager_is_combat_v1_authority")
		== false
	)
	assert(
		GladiatorProgressionManager.canonical_specialization_id("balanced") == "gladiator",
		"balanced must migrate to gladiator",
	)
	assert(
		GladiatorProgressionManager.canonical_specialization_id("thraex") == "dimachaerus",
		"thraex must migrate to dimachaerus",
	)


func _assert_trait_catalog() -> void:
	assert(
		TraitManager.get_normal_trait_ids().size() == 16,
		"The frozen catalog must contain sixteen normal traits",
	)
	assert(
		TraitManager.get_origin_trait_ids().is_empty(),
		"The frozen model must not expose a separate origin-trait catalog",
	)
	assert(
		TraitManager.get_obtainable_trait_ids().is_empty(),
		"The legacy obtainable-trait catalog must remain inactive",
	)

	var disciplined := TraitManager.get_trait("disciplined")
	var impulsive := TraitManager.get_trait("impulsive")
	var reckless := TraitManager.get_trait("reckless")
	var prudent := TraitManager.get_trait("prudent")
	assert(
		disciplined.get("incompatible_with", []).has("impulsive"),
		"Disciplinado must reject Impulsivo",
	)
	assert(
		impulsive.get("incompatible_with", []).has("disciplined"),
		"Impulsivo must reject Disciplinado",
	)
	assert(reckless.get("incompatible_with", []).has("prudent"), "Temerario must reject Prudente")
	assert(prudent.get("incompatible_with", []).has("reckless"), "Prudente must reject Temerario")
	assert(
		TraitManager.get_trait("dreamer").is_empty(),
		"Removed legacy traits must not remain active catalog entries",
	)


func _assert_equipment_contracts() -> void:
	var shield_charge: Dictionary = GladiatorProgressionManager.abilities.get("shield_charge", {})
	var cast_net: Dictionary = GladiatorProgressionManager.abilities.get("cast_net", {})
	var two_blades: Dictionary = GladiatorProgressionManager.abilities.get(
		"dance_of_two_blades", {}
	)
	assert(
		shield_charge.get("required_equipment_tags", []).has("shield"),
		"Legacy Embate del escudo compatibility data must preserve its shield requirement",
	)
	assert(
		cast_net.get("required_equipment_tags", []).has("net"),
		"Legacy Red de captura compatibility data must preserve its net requirement",
	)
	assert(
		two_blades.get("required_equipment_tags", []).has("dual_blades"),
		"Legacy Danza de dos filos compatibility data must preserve its dual-blades requirement",
	)
	assert(
		EquipmentManager.recipes.has("retiarius_kit"),
		"The forge must define the net and trident recipe",
	)
	assert(
		EquipmentManager.recipes.has("dual_blades"), "The forge must define the dual blades recipe"
	)
	assert(
		ReconciliationPolicy.get_contract().get("legacy_specialization_skill_mapping_allowed")
		== false,
		"Legacy equipment-gated class abilities must not define canonical skill mapping",
	)


func _assert_migration_contracts() -> void:
	assert(
		(
			GladiatorProgressionManager.canonical_tactical_condition("target_defending")
			== "target_guarding"
		),
		"Legacy defending condition must migrate",
	)
	assert(
		(
			GladiatorProgressionManager.canonical_tactical_condition("after_dodge_or_block")
			== "after_defense"
		),
		"Legacy defense reaction condition must migrate",
	)
	assert(
		GladiatorProgressionManager.canonical_tactical_condition("unknown") == "always",
		"Unknown conditions must fall back safely",
	)


func _assert_save_contract() -> void:
	assert(SaveManager.SAVE_VERSION == 14, "The current save format must be version 14")
	var person = preload("res://scripts/entities/person.gd").new(
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
	var serialized: Dictionary = SaveManager._serialize_person(person)
	assert(int(serialized.get("technique", 0)) == 7, "Technique must be serialized")
	assert(int(serialized.get("health", 0)) == 65, "Health must be serialized")
	assert(
		serialized.get("traits", []).has("dreamer"),
		"Legacy trait ids must still round-trip through Save v14",
	)
	assert(
		serialized.get("applied_trait_effects", []).has("dreamer"),
		"Legacy applied trait effects must still round-trip through Save v14",
	)