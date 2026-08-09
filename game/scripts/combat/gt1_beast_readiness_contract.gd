extends RefCounted

const REQUIRED_BEAST_IDS: Array[String] = ["bear", "boar", "lion"]
const REQUIRED_COMBAT_STATS: Array[String] = ["FUE", "AGI", "TEC", "RES", "PV"]


func evaluate(beasts: Array, runtime_adapter_ready: bool = false) -> Dictionary:
	var missing_beast_ids: Array[String] = []
	var missing_stats_by_beast: Dictionary = {}
	var invalid_stats_by_beast: Dictionary = {}
	var seen_ids: Array[String] = []

	for raw_beast in beasts:
		if not raw_beast is Dictionary:
			continue
		var beast := raw_beast as Dictionary
		var beast_id := str(beast.get("id", ""))
		if not REQUIRED_BEAST_IDS.has(beast_id):
			continue
		seen_ids.append(beast_id)
		var missing_stats: Array[String] = []
		var invalid_stats: Array[String] = []
		for stat_id in REQUIRED_COMBAT_STATS:
			if not beast.has(stat_id):
				missing_stats.append(stat_id)
				continue
			if not _is_numeric(beast.get(stat_id)):
				invalid_stats.append(stat_id)
		if not missing_stats.is_empty():
			missing_stats_by_beast[beast_id] = missing_stats
		if not invalid_stats.is_empty():
			invalid_stats_by_beast[beast_id] = invalid_stats

	for beast_id in REQUIRED_BEAST_IDS:
		if not seen_ids.has(beast_id):
			missing_beast_ids.append(beast_id)

	var stats_ready := (
		missing_beast_ids.is_empty()
		and missing_stats_by_beast.is_empty()
		and invalid_stats_by_beast.is_empty()
	)
	var beast_selection_ready := stats_ready and runtime_adapter_ready
	return {
		"status": "ready" if beast_selection_ready else "blocked",
		"month": 16,
		"month_16_allows_beasts": true,
		"human_selection_ready": true,
		"beast_selection_ready": beast_selection_ready,
		"canonical_beast_stats_ready": stats_ready,
		"runtime_beast_adapter_ready": runtime_adapter_ready,
		"missing_beast_ids": missing_beast_ids.duplicate(),
		"missing_stats_by_beast": missing_stats_by_beast.duplicate(true),
		"invalid_stats_by_beast": invalid_stats_by_beast.duplicate(true),
		"required_combat_stats": REQUIRED_COMBAT_STATS.duplicate(),
		"invent_stats_allowed": false,
		"fallback_to_human_stats_allowed": false,
		"reason": _reason(stats_ready, runtime_adapter_ready),
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"month": 16,
		"month_16_allows_beasts": true,
		"required_beast_ids": REQUIRED_BEAST_IDS.duplicate(),
		"required_combat_stats": REQUIRED_COMBAT_STATS.duplicate(),
		"stats_source": "explicit_canonical_beast_data",
		"runtime_adapter_requirement": "explicit_ready_signal",
		"invent_stats_allowed": false,
		"fallback_to_human_stats_allowed": false,
		"blocked_behavior": "human_only_selection_remains_available",
	}


func _is_numeric(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


func _reason(stats_ready: bool, runtime_adapter_ready: bool) -> String:
	if not stats_ready and not runtime_adapter_ready:
		return "missing_canonical_beast_combat_stats_and_runtime_adapter"
	if not stats_ready:
		return "missing_canonical_beast_combat_stats"
	if not runtime_adapter_ready:
		return "missing_runtime_beast_adapter"
	return ""
