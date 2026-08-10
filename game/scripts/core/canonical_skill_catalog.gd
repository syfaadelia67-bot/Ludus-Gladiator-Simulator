extends RefCounted

const ReconciliationPolicy = preload("res://scripts/core/skill_ability_reconciliation_policy.gd")


static func get_contract() -> Dictionary:
	return ReconciliationPolicy.get_contract()


static func get_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_entry in DataRepository.get_skills():
		if raw_entry is Dictionary:
			result.append(ReconciliationPolicy.canonical_skill_identity(raw_entry as Dictionary))
	return result


static func get_skill(skill_id: String) -> Dictionary:
	var entry: Dictionary = DataRepository.get_skill(skill_id)
	if entry.is_empty():
		return {}
	return ReconciliationPolicy.canonical_skill_identity(entry)


static func has_skill(skill_id: String) -> bool:
	return not get_skill(skill_id).is_empty()


static func get_general_skills() -> Array[Dictionary]:
	return _by_category("general")


static func get_specialized_skills() -> Array[Dictionary]:
	return _by_category("specialized")


static func resolve_legacy_ability_as_skill(_ability_id: String) -> Dictionary:
	# Deliberately fail closed. An identical id (for example `feint`) does not
	# authorize importing legacy energy, damage, Intelligence, status or levels.
	return {}


static func can_progress_skills() -> bool:
	return ReconciliationPolicy.can_progress_canonical_skills()


static func _by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in get_skills():
		if str(entry.get("category", "")) == category:
			result.append(entry)
	return result
