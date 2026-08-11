extends RefCounted

const CANONICAL_SKILL_IDS: Array[String] = [
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
const REQUIRED_MECHANICS_SECTIONS: Array[String] = [
	"action_mapping",
	"cost",
	"timing",
	"targets",
	"equipment_requirements",
	"effects",
]
const FORBIDDEN_LEGACY_KEYS: Array[String] = [
	"ability_id",
	"legacy_ability_id",
	"energy",
	"energy_cost",
	"intelligence",
	"cooldown_seconds",
	"primary_stats",
]
const APPROVED_SOURCE := "approved_combat_v1_design"


func evaluate(
	skill_identities: Array, mechanics_entries: Array, runtime_resolver_ready: bool = false
) -> Dictionary:
	var errors: Array[String] = []
	var identity_ids := _sorted_identity_ids(skill_identities)
	var expected_ids := CANONICAL_SKILL_IDS.duplicate()
	expected_ids.sort()
	var identity_ready := identity_ids == expected_ids
	if not identity_ready:
		errors.append("Canonical Combat V1 skill identity catalog must contain exactly twelve ids")

	var indexed := _index_entries(mechanics_entries, errors)
	var missing_mechanics_ids: Array[String] = []
	var missing_progression_ids: Array[String] = []
	for skill_id in expected_ids:
		if not indexed.has(skill_id):
			missing_mechanics_ids.append(skill_id)
			missing_progression_ids.append(skill_id)
			continue
		var entry := indexed[skill_id] as Dictionary
		_validate_entry(skill_id, entry, errors, missing_progression_ids)

	var mechanics_ready := missing_mechanics_ids.is_empty() and errors.is_empty()
	var progression_ready := missing_progression_ids.is_empty() and errors.is_empty()
	var design_ready := identity_ready and mechanics_ready and progression_ready
	return {
		"status": "ready" if design_ready and runtime_resolver_ready else "blocked",
		"ready": design_ready and runtime_resolver_ready,
		"identity_ready": identity_ready,
		"mechanics_ready": mechanics_ready,
		"progression_ready": progression_ready,
		"design_ready": design_ready,
		"runtime_resolver_ready": runtime_resolver_ready,
		"missing_mechanics_ids": missing_mechanics_ids.duplicate(),
		"missing_progression_ids": missing_progression_ids.duplicate(),
		"errors": errors.duplicate(),
		"legacy_ability_import_allowed": false,
		"invent_mechanics_allowed": false,
		"save_version_change_required": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen_boundary",
		"canonical_identity_source": "DataRepository.skills",
		"canonical_mechanics_source": "DataRepository.skill_mechanics_v1",
		"required_skill_ids": CANONICAL_SKILL_IDS.duplicate(),
		"required_mechanics_sections": REQUIRED_MECHANICS_SECTIONS.duplicate(),
		"approved_source": APPROVED_SOURCE,
		"legacy_ability_import_allowed": false,
		"legacy_progression_import_allowed": false,
		"invent_mechanics_allowed": false,
		"runtime_requires_frozen_design": true,
		"save_version_change_required": false,
	}


func _validate_entry(
	skill_id: String,
	entry: Dictionary,
	errors: Array[String],
	missing_progression_ids: Array[String]
) -> void:
	if str(entry.get("status", "")) != "frozen":
		errors.append("Skill %s mechanics must be explicitly marked frozen" % skill_id)
	if str(entry.get("source", "")) != APPROVED_SOURCE:
		errors.append("Skill %s mechanics must come from approved Combat V1 design" % skill_id)
	var mechanics_value: Variant = entry.get("mechanics", null)
	if not mechanics_value is Dictionary:
		errors.append("Skill %s mechanics must be a Dictionary" % skill_id)
	else:
		_validate_mechanics_sections(skill_id, mechanics_value as Dictionary, errors)
	var progression_value: Variant = entry.get("progression", null)
	if not progression_value is Dictionary or (progression_value as Dictionary).is_empty():
		missing_progression_ids.append(skill_id)
	elif str((progression_value as Dictionary).get("status", "")) != "frozen":
		missing_progression_ids.append(skill_id)
		errors.append("Skill %s progression must be explicitly marked frozen" % skill_id)
	_append_forbidden_legacy_keys(entry, skill_id, errors)


func _validate_mechanics_sections(
	skill_id: String, mechanics: Dictionary, errors: Array[String]
) -> void:
	for section in REQUIRED_MECHANICS_SECTIONS:
		if not mechanics.has(section):
			errors.append("Skill %s is missing mechanics section %s" % [skill_id, section])
			continue
		var value: Variant = mechanics.get(section)
		if section == "equipment_requirements":
			if not value is Array:
				errors.append("Skill %s equipment_requirements must be an Array" % skill_id)
		elif not value is Dictionary or (value as Dictionary).is_empty():
			errors.append("Skill %s mechanics section %s must be explicit" % [skill_id, section])


func _index_entries(entries: Array, errors: Array[String]) -> Dictionary:
	var indexed: Dictionary = {}
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			errors.append("Combat V1 skill mechanics catalog contains a non-Dictionary entry")
			continue
		var entry := raw_entry as Dictionary
		var skill_id := str(entry.get("id", ""))
		if not CANONICAL_SKILL_IDS.has(skill_id):
			errors.append("Unknown Combat V1 skill mechanics id: %s" % skill_id)
			continue
		if indexed.has(skill_id):
			errors.append("Duplicate Combat V1 skill mechanics id: %s" % skill_id)
			continue
		indexed[skill_id] = entry
	return indexed


func _append_forbidden_legacy_keys(
	value: Variant, skill_id: String, errors: Array[String], path: String = ""
) -> void:
	if value is Dictionary:
		for raw_key in (value as Dictionary).keys():
			var key := str(raw_key)
			var child_path := key if path.is_empty() else "%s.%s" % [path, key]
			if FORBIDDEN_LEGACY_KEYS.has(key):
				errors.append("Skill %s contains forbidden legacy field %s" % [skill_id, child_path])
			_append_forbidden_legacy_keys((value as Dictionary).get(raw_key), skill_id, errors, child_path)
	elif value is Array:
		for index in range((value as Array).size()):
			_append_forbidden_legacy_keys(
				(value as Array)[index], skill_id, errors, "%s[%d]" % [path, index]
			)


func _sorted_identity_ids(entries: Array) -> Array[String]:
	var ids: Array[String] = []
	for raw_entry in entries:
		if raw_entry is Dictionary:
			var skill_id := str((raw_entry as Dictionary).get("id", ""))
			if not skill_id.is_empty():
				ids.append(skill_id)
	ids.sort()
	return ids
