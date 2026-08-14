extends RefCounted

const CombatStatAdapterScript = preload("res://scripts/core/combat_stat_adapter.gd")

var _stat_adapter = CombatStatAdapterScript.new()


func build_from_person(person, team_id: String, equipment_stats: Dictionary = {}) -> Dictionary:
	if person == null:
		return {
			"status": "invalid_source",
			"errors": ["Combat roster fighter requires a person source"],
			"pending_stat_ids": [],
			"fighter": {},
			"legacy_separate": {},
			"legacy_unmapped": {},
		}
	var source := {
		"id": str(person.id),
		"strength": int(person.strength),
		"agility": int(person.agility),
		"technique": int(person.technique),
		"resistance": int(person.resistance),
		"health": int(person.health),
		"endurance": int(person.endurance),
		"stamina": 10.0,
	}
	return build_fighter(source, team_id, equipment_stats)


func build_fighter(
	person_source: Dictionary,
	team_id: String,
	equipment_stats: Dictionary = {},
	canonical_overrides: Dictionary = {}
) -> Dictionary:
	var source := person_source.duplicate(true)
	for key in ["strength", "agility", "technique", "health", "resistance"]:
		if canonical_overrides.has(key):
			source[key] = canonical_overrides[key]

	var adapted: Dictionary = _stat_adapter.from_legacy(source)
	var pending: Array[String] = _stat_adapter.get_pending_stat_ids(adapted)
	var legacy_separate := (adapted.get("legacy_separate", {}) as Dictionary).duplicate(true)
	if not pending.is_empty():
		return {
			"status": "pending_canonical_stats",
			"errors": [],
			"pending_stat_ids": pending.duplicate(),
			"fighter": {},
			"legacy_separate": legacy_separate.duplicate(true),
			"legacy_unmapped": legacy_separate.duplicate(true),
		}

	var fighter_id := str(person_source.get("id", ""))
	if fighter_id.is_empty() or team_id.is_empty():
		return {
			"status": "invalid_source",
			"errors": ["Combat roster fighter requires non-empty id and team_id"],
			"pending_stat_ids": [],
			"fighter": {},
			"legacy_separate": {},
			"legacy_unmapped": {},
		}

	var skill_context_value: Variant = equipment_stats.get("skill_context", {})
	var skill_context := (
		(skill_context_value as Dictionary).duplicate(true)
		if skill_context_value is Dictionary
		else {}
	)
	return {
		"status": "ready",
		"errors": [],
		"pending_stat_ids": [],
		"fighter":
		{
			"id": fighter_id,
			"team": team_id,
			"entity_type": "gladiator",
			"stats": (adapted.get("stats", {}) as Dictionary).duplicate(true),
			"stamina": float(person_source.get("stamina", 10.0)),
			"equipment":
			{
				"power": int(equipment_stats.get("power", 0)),
				"defense": int(equipment_stats.get("defense", 0)),
			},
			"equipment_context": skill_context,
		},
		"legacy_separate": legacy_separate.duplicate(true),
		"legacy_unmapped": legacy_separate.duplicate(true),
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"legacy_mapping":
		{
			"strength": "FUE",
			"agility": "AGI",
			"technique": "TEC",
			"resistance": "RES",
			"health": "PV",
		},
		"live_roster_res_source": "person.resistance",
		"legacy_missing_resistance_baseline": 5,
		"legacy_separate_stats": ["endurance"],
		"removed_legacy_stats": ["intelligence"],
		"endurance_to_resistance_fallback": false,
		"endurance_to_stamina_fallback": false,
		"intelligence_used_by_combat_v1": false,
		"missing_canonical_stats": "fail_closed",
		"equipment_source": "explicit_power_defense_snapshot",
		"skill_equipment_context_source": "explicit_canonical_equipped_slots_and_tags",
		"save_version_change_required": false,
	}
