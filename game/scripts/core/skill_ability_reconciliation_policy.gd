extends RefCounted

const STATUS := "canonical_skill_identity_legacy_ability_quarantined"


static func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"canonical_skill_source": "DataRepository.skills",
		"canonical_skill_mechanics_source": "DataRepository.skill_mechanics_v1",
		"legacy_ability_source": "DataRepository.abilities",
		"canonical_skill_count": 12,
		"canonical_general_skill_count": 8,
		"canonical_specialized_skill_count": 4,
		"canonical_skill_identity_ready": true,
		"canonical_skill_mechanics_ready": false,
		"canonical_skill_progression_ready": false,
		"legacy_abilities_retained_for_compatibility": true,
		"legacy_abilities_allowed_in_combat_v1": false,
		"legacy_ability_levels_allowed_in_combat_v1": false,
		"legacy_specialization_class_ability_is_canonical_skill": false,
		"legacy_progression_manager_is_combat_v1_authority": false,
		"legacy_specialization_skill_mapping_allowed": false,
		"shared_id_inherits_legacy_mechanics": false,
		"invent_skill_mechanics_allowed": false,
		"save_version_change_required": false,
	}


static func canonical_skill_identity(entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return {}
	return {
		"id": str(entry.get("id", "")),
		"name": str(entry.get("name", "")),
		"category": str(entry.get("category", "")),
	}


static func is_legacy_ability_allowed_in_combat_v1(_ability_id: String) -> bool:
	return false


static func can_progress_canonical_skills() -> bool:
	return false