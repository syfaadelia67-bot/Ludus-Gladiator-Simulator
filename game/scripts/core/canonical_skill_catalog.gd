extends RefCounted

const ReconciliationPolicy = preload("res://scripts/core/skill_ability_reconciliation_policy.gd")


static func get_contract() -> Dictionary:
	return ReconciliationPolicy.get_contract()


static func get_skills(repository: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if repository == null or not repository.has_method("get_skills"):
		return result
	var raw_skills: Variant = repository.call("get_skills")
	if not raw_skills is Array:
		return result
	for raw_entry in raw_skills as Array:
		if raw_entry is Dictionary:
			result.append(ReconciliationPolicy.canonical_skill_identity(raw_entry as Dictionary))
	return result


static func get_skill(repository: Object, skill_id: String) -> Dictionary:
	if repository == null or not repository.has_method("get_skill"):
		return {}
	var raw_entry: Variant = repository.call("get_skill", skill_id)
	if not raw_entry is Dictionary:
		return {}
	var entry := raw_entry as Dictionary
	if entry.is_empty():
		return {}
	return ReconciliationPolicy.canonical_skill_identity(entry)


static func has_skill(repository: Object, skill_id: String) -> bool:
	return not get_skill(repository, skill_id).is_empty()


static func get_general_skills(repository: Object) -> Array[Dictionary]:
	return _by_category(repository, "general")


static func get_specialized_skills(repository: Object) -> Array[Dictionary]:
	return _by_category(repository, "specialized")


static func resolve_legacy_ability_as_skill(_ability_id: String) -> Dictionary:
	# Deliberately fail closed. An identical id (for example `feint`) does not
	# authorize importing legacy energy, damage, Intelligence, status or levels.
	return {}


static func can_progress_skills() -> bool:
	return ReconciliationPolicy.can_progress_canonical_skills()


static func _by_category(repository: Object, category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in get_skills(repository):
		if str(entry.get("category", "")) == category:
			result.append(entry)
	return result
