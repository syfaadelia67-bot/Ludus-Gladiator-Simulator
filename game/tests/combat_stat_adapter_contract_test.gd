extends Node

const CombatStatAdapterScript = preload("res://scripts/core/combat_stat_adapter.gd")


func _ready() -> void:
	var adapter = CombatStatAdapterScript.new()
	_assert_complete_mapping(adapter)
	_assert_resistance_is_not_invented(adapter)
	_assert_missing_sources_are_explicit(adapter)
	print("Canonical combat stat adapter contract: OK")
	get_tree().quit(0)


func _assert_complete_mapping(adapter) -> void:
	var source := {
		"strength": 11,
		"agility": 12,
		"technique": 13,
		"resistance": 14,
		"health": 15,
		"endurance": 16,
		"intelligence": 17,
	}
	var before := source.duplicate(true)
	var adapted: Dictionary = adapter.from_legacy(source)
	var stats: Dictionary = adapted.get("stats", {})
	assert(adapter.CANONICAL_STAT_IDS == ["FUE", "AGI", "TEC", "RES", "PV"])
	assert(stats.get("FUE") == 11, "FUE must read legacy strength")
	assert(stats.get("AGI") == 12, "AGI must read legacy agility")
	assert(stats.get("TEC") == 13, "TEC must read legacy technique")
	assert(stats.get("RES") == 14, "RES must read explicit legacy resistance")
	assert(stats.get("PV") == 15, "PV must read legacy health")
	assert(adapter.is_complete(adapted), "Explicit canonical sources must produce a complete view")
	assert(source == before, "The adapter must never mutate Save v14 legacy input")
	var unmapped: Dictionary = adapted.get("legacy_unmapped", {})
	assert(unmapped.get("endurance") == 16, "Legacy endurance must remain visible but unmapped")
	assert(unmapped.get("intelligence") == 17, "Legacy intelligence must remain visible but unmapped")


func _assert_resistance_is_not_invented(adapter) -> void:
	var adapted: Dictionary = adapter.from_legacy(
		{
			"strength": 21,
			"agility": 22,
			"technique": 23,
			"health": 24,
			"endurance": 99,
		}
	)
	var stats: Dictionary = adapted.get("stats", {})
	assert(stats.has("RES"), "The canonical view must always expose RES")
	assert(stats["RES"] == null, "RES must stay unresolved without explicit resistance")
	assert(
		adapter.get_pending_stat_ids(adapted) == ["RES"],
		"Missing resistance must be explicit instead of falling back to endurance"
	)
	assert(not adapter.is_complete(adapted), "An unresolved RES mapping must keep the view incomplete")


func _assert_missing_sources_are_explicit(adapter) -> void:
	var adapted: Dictionary = adapter.from_legacy({"strength": 31})
	var pending: Array[String] = adapter.get_pending_stat_ids(adapted)
	assert(pending == ["AGI", "TEC", "RES", "PV"])
	var stats: Dictionary = adapted.get("stats", {})
	for stat_id in adapter.CANONICAL_STAT_IDS:
		assert(stats.has(stat_id), "Canonical stat view must expose %s even when unresolved" % stat_id)
