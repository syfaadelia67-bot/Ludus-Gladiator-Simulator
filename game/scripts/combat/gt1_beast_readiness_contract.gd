extends RefCounted

const BeastCombatV1DataContractScript = preload(
	"res://scripts/core/beast_combat_v1_data_contract.gd"
)
const REQUIRED_BEAST_IDS: Array[String] = ["bear", "boar", "lion"]
const REQUIRED_COMBAT_STATS: Array[String] = ["FUE", "AGI", "TEC", "RES", "PV"]
const REQUIRED_STAMINA_FIELD := "stamina"

var _data_contract = BeastCombatV1DataContractScript.new()


func evaluate(beasts: Array, runtime_adapter_ready: bool = false) -> Dictionary:
	var missing_beast_ids: Array[String] = []
	var missing_stats_by_beast: Dictionary = {}
	var invalid_stats_by_beast: Dictionary = {}
	var mismatched_profiles: Array[String] = []
	var seen_ids: Array[String] = []
	var profile_errors: Array[String] = _data_contract.validate_entries(beasts)

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
		if not beast.has(REQUIRED_STAMINA_FIELD):
			missing_stats.append(REQUIRED_STAMINA_FIELD)
		elif not _is_numeric(beast.get(REQUIRED_STAMINA_FIELD)):
			invalid_stats.append(REQUIRED_STAMINA_FIELD)
		if not missing_stats.is_empty():
			missing_stats_by_beast[beast_id] = missing_stats
		if not invalid_stats.is_empty():
			invalid_stats_by_beast[beast_id] = invalid_stats
		if missing_stats.is_empty() and invalid_stats.is_empty():
			if not _matches_canonical_profile(beast_id, beast):
				mismatched_profiles.append(beast_id)

	for beast_id in REQUIRED_BEAST_IDS:
		if not seen_ids.has(beast_id):
			missing_beast_ids.append(beast_id)

	var stats_ready := (
		missing_beast_ids.is_empty()
		and missing_stats_by_beast.is_empty()
		and invalid_stats_by_beast.is_empty()
		and mismatched_profiles.is_empty()
		and profile_errors.is_empty()
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
		"mismatched_profiles": mismatched_profiles.duplicate(),
		"profile_errors": profile_errors.duplicate(),
		"required_combat_stats": REQUIRED_COMBAT_STATS.duplicate(),
		"required_stamina_field": REQUIRED_STAMINA_FIELD,
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
		"required_stamina_field": REQUIRED_STAMINA_FIELD,
		"canonical_profiles": _data_contract.get_profiles(),
		"stats_source": "explicit_canonical_beast_data",
		"runtime_adapter_requirement": "explicit_ready_signal",
		"invent_stats_allowed": false,
		"fallback_to_human_stats_allowed": false,
		"blocked_behavior": "human_only_selection_remains_available",
	}


func _matches_canonical_profile(beast_id: String, beast: Dictionary) -> bool:
	var expected := _data_contract.get_profile(beast_id)
	if expected.is_empty():
		return false
	for stat_id in REQUIRED_COMBAT_STATS:
		if float(beast.get(stat_id, -1.0)) != float(expected.get(stat_id, -2.0)):
			return false
	return (
		float(beast.get(REQUIRED_STAMINA_FIELD, -1.0))
		== float(expected.get(REQUIRED_STAMINA_FIELD, -2.0))
	)


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
