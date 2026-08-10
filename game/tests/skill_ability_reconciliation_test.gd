extends SceneTree

const CanonicalSkillCatalog = preload("res://scripts/core/canonical_skill_catalog.gd")
const ReconciliationPolicy = preload("res://scripts/core/skill_ability_reconciliation_policy.gd")
const DemoPreAssetReadiness = preload("res://scripts/core/demo_pre_asset_readiness.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_canonical_catalog_is_exact_and_identity_only()
	_test_legacy_abilities_cannot_resolve_as_combat_v1_skills()
	_test_shared_ids_do_not_inherit_legacy_mechanics()
	_test_specialization_class_abilities_stay_legacy()
	_test_progression_fails_closed_until_skill_mechanics_are_frozen()
	_test_readiness_closes_reconciliation_without_hiding_design_blocker()
	if _failures.is_empty():
		print("Skill / ability reconciliation: OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_canonical_catalog_is_exact_and_identity_only() -> void:
	var skills := CanonicalSkillCatalog.get_skills()
	_assert_eq(skills.size(), 12, "Combat V1 must expose exactly twelve canonical skills")
	_assert_eq(
		CanonicalSkillCatalog.get_general_skills().size(),
		8,
		"Combat V1 must expose exactly eight general skills",
	)
	_assert_eq(
		CanonicalSkillCatalog.get_specialized_skills().size(),
		4,
		"Combat V1 must expose exactly four specialized skills",
	)
	for skill in skills:
		_assert_eq(
			(skill as Dictionary).keys().size(),
			3,
			"canonical skill snapshots must contain identity only",
		)


func _test_legacy_abilities_cannot_resolve_as_combat_v1_skills() -> void:
	_assert_true(
		not DataRepository.abilities.is_empty(),
		"legacy abilities must remain available for compatibility until legacy combat is retired",
	)
	_assert_true(
		CanonicalSkillCatalog.get_skill("precise_strike").is_empty(),
		"legacy-only precise_strike must not become a canonical skill",
	)
	_assert_true(
		CanonicalSkillCatalog.resolve_legacy_ability_as_skill("precise_strike").is_empty(),
		"legacy ability fallback into Combat V1 skills must fail closed",
	)
	_assert_eq(
		ReconciliationPolicy.is_legacy_ability_allowed_in_combat_v1("precise_strike"),
		false,
		"legacy abilities must never be Combat V1 authority",
	)


func _test_shared_ids_do_not_inherit_legacy_mechanics() -> void:
	var canonical_feint := CanonicalSkillCatalog.get_skill("feint")
	var legacy_feint := _legacy_ability("feint")
	_assert_true(not canonical_feint.is_empty(), "canonical Finta must exist")
	_assert_true(not legacy_feint.is_empty(), "legacy Finta compatibility data must still exist")
	_assert_eq(
		canonical_feint.keys().size(),
		3,
		"canonical Finta must expose only id/name/category",
	)
	_assert_true(
		legacy_feint.has("levels"),
		"test fixture must prove the legacy shared-id entry still carries old mechanics",
	)
	_assert_true(
		not canonical_feint.has("levels"),
		"shared id must not import legacy levels into canonical Finta",
	)
	_assert_true(
		not canonical_feint.has("primary_stats"),
		"shared id must not import legacy Intelligence/stat dependencies",
	)
	_assert_eq(
		ReconciliationPolicy.get_contract().get("shared_id_inherits_legacy_mechanics"),
		false,
		"policy must explicitly reject shared-id mechanic inheritance",
	)


func _test_specialization_class_abilities_stay_legacy() -> void:
	for raw_specialization in DataRepository.specializations:
		if not raw_specialization is Dictionary:
			continue
		var specialization := raw_specialization as Dictionary
		var class_ability := str(specialization.get("class_ability", ""))
		if class_ability.is_empty():
			continue
		_assert_true(
			CanonicalSkillCatalog.get_skill(class_ability).is_empty(),
			(
				"legacy specialization class_ability must not silently become a canonical skill: %s"
				% class_ability
			),
		)
	_assert_eq(
		ReconciliationPolicy.get_contract().get(
			"legacy_specialization_class_ability_is_canonical_skill"
		),
		false,
		"specialization class_ability links must remain legacy-only",
	)


func _test_progression_fails_closed_until_skill_mechanics_are_frozen() -> void:
	var contract := ReconciliationPolicy.get_contract()
	_assert_eq(
		contract.get("canonical_skill_identity_ready"),
		true,
		"canonical skill identity must be ready after reconciliation",
	)
	_assert_eq(
		contract.get("canonical_skill_mechanics_ready"),
		false,
		"skill mechanics must remain pending rather than inferred from abilities",
	)
	_assert_eq(
		contract.get("canonical_skill_progression_ready"),
		false,
		"skill progression must remain pending until explicitly frozen",
	)
	_assert_eq(
		CanonicalSkillCatalog.can_progress_skills(),
		false,
		"canonical skill progression must fail closed",
	)


func _test_readiness_closes_reconciliation_without_hiding_design_blocker() -> void:
	var codes := DemoPreAssetReadiness.new().get_blocker_codes()
	_assert_true(
		not codes.has("canonical_skill_progression_reconciliation"),
		"Part 7 reconciliation architecture blocker must be closed",
	)
	_assert_true(
		codes.has("canonical_skill_mechanics_not_frozen"),
		"unfrozen skill mechanics must remain an explicit design blocker",
	)


func _legacy_ability(ability_id: String) -> Dictionary:
	for raw_entry in DataRepository.abilities:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("id", "")) == ability_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
