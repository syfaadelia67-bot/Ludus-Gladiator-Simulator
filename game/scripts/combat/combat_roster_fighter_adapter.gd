extends RefCounted

const CombatStatAdapterScript = preload("res://scripts/core/combat_stat_adapter.gd")

var _stat_adapter = CombatStatAdapterScript.new()


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

	return {
		"status": "ready",
		"errors": [],
		"pending_stat_ids": [],
		"fighter":
		{
			"id": fighter_id,
			"team": team_id,
			"stats": (adapted.get("stats", {}) as Dictionary).duplicate(true),
			"stamina": float(person_source.get("stamina", 10.0)),
			"equipment":
			{
				"power": int(equipment_stats.get("power", 0)),
				"defense": int(equipment_stats.get("defense", 0)),
			},
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
		"legacy_separate_stats": ["endurance"],
		"removed_legacy_stats": ["intelligence"],
		"endurance_to_resistance_fallback": false,
		"endurance_to_stamina_fallback": false,
		"intelligence_used_by_combat_v1": false,
		"missing_canonical_stats": "fail_closed",
		"equipment_source": "explicit_power_defense_snapshot",
		"save_version_change_required": false,
	}
