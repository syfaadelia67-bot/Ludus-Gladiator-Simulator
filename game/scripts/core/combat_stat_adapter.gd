extends RefCounted

const CANONICAL_STAT_IDS: Array[String] = ["FUE", "AGI", "TEC", "RES", "PV"]
const LEGACY_SOURCE_FIELDS := {
	"FUE": "strength",
	"AGI": "agility",
	"TEC": "technique",
	"RES": "resistance",
	"PV": "health",
}
const LEGACY_SEPARATE_FIELDS: Array[String] = ["endurance"]
const REMOVED_LEGACY_FIELDS: Array[String] = ["intelligence"]


func from_legacy(source: Dictionary) -> Dictionary:
	var stats: Dictionary = {}
	var pending: Array[String] = []
	for canonical_id in CANONICAL_STAT_IDS:
		var legacy_field := str(LEGACY_SOURCE_FIELDS[canonical_id])
		if source.has(legacy_field):
			stats[canonical_id] = source[legacy_field]
		else:
			stats[canonical_id] = null
			pending.append(canonical_id)

	var legacy_separate: Dictionary = {}
	for legacy_field in LEGACY_SEPARATE_FIELDS:
		if source.has(legacy_field):
			legacy_separate[legacy_field] = source[legacy_field]

	return {
		"stats": stats,
		"pending": pending,
		"legacy_separate": legacy_separate,
		# Compatibility alias while callers migrate to the explicit separate bucket.
		"legacy_unmapped": legacy_separate.duplicate(true),
	}


func is_complete(adapted: Dictionary) -> bool:
	var pending: Variant = adapted.get("pending", [])
	return pending is Array and (pending as Array).is_empty()


func get_pending_stat_ids(adapted: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var pending: Variant = adapted.get("pending", [])
	if not pending is Array:
		return result
	for raw_stat_id in pending as Array:
		var stat_id := str(raw_stat_id)
		if CANONICAL_STAT_IDS.has(stat_id) and not result.has(stat_id):
			result.append(stat_id)
	return result
