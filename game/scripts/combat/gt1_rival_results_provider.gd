extends RefCounted

const GT1RivalResultRegistryScript = preload("res://scripts/combat/gt1_rival_result_registry.gd")

const REQUIRED_RIVAL_RESULTS := 7
const POINTS_PER_WIN := 3
const MAX_POINTS := 27
const MAX_WINS := 9

var _registry = GT1RivalResultRegistryScript.new()


func validate_explicit_results(results: Array) -> Dictionary:
	var canonical_ids: Array[String] = []
	for raw_ludus in DataRepository.get_rival_ludi():
		if not raw_ludus is Dictionary:
			return _rejected(
				"invalid_canonical_rival_catalog",
				["Canonical rival Ludus catalog contains a non-Dictionary entry"],
			)
		var rival_id := str((raw_ludus as Dictionary).get("id", ""))
		if rival_id.is_empty() or canonical_ids.has(rival_id):
			return _rejected(
				"invalid_canonical_rival_catalog",
				["Canonical rival Ludus ids must be non-empty and unique"],
			)
		canonical_ids.append(rival_id)
	canonical_ids.sort()
	if canonical_ids.size() != REQUIRED_RIVAL_RESULTS:
		return _rejected(
			"invalid_canonical_rival_catalog",
			[
				"GT I requires exactly %d canonical rival Ludi" % REQUIRED_RIVAL_RESULTS,
			],
		)
	if results.size() != REQUIRED_RIVAL_RESULTS:
		return _rejected(
			"incomplete_rival_results_batch",
			[
				(
					"GT I rival results provider requires exactly %d explicit results"
					% REQUIRED_RIVAL_RESULTS
				),
			],
		)

	var results_by_id: Dictionary = {}
	for raw_result in results:
		if not raw_result is Dictionary:
			return _rejected(
				"invalid_rival_result_entry",
				["Every GT I rival result must be a Dictionary"],
			)
		var entry := raw_result as Dictionary
		var rival_id := str(entry.get("rival_id", ""))
		if not canonical_ids.has(rival_id):
			return _rejected(
				"unknown_rival_ludus",
				["Unknown canonical rival Ludus id: %s" % rival_id],
			)
		if results_by_id.has(rival_id):
			return _rejected(
				"duplicate_rival_result",
				["GT I rival result is duplicated for %s" % rival_id],
			)
		var points_value: Variant = entry.get("points", null)
		var wins_value: Variant = entry.get("wins", null)
		if not _is_integral_number(points_value) or not _is_integral_number(wins_value):
			return _rejected(
				"invalid_rival_score_type",
				["GT I rival points and wins must be whole numbers"],
			)
		var points := int(points_value)
		var wins := int(wins_value)
		if points < 0 or points > MAX_POINTS:
			return _rejected(
				"invalid_rival_points",
				["GT I rival points must be between 0 and %d" % MAX_POINTS],
			)
		if wins < 0 or wins > MAX_WINS:
			return _rejected(
				"invalid_rival_wins",
				["GT I rival wins must be between 0 and %d" % MAX_WINS],
			)
		if points != wins * POINTS_PER_WIN:
			return _rejected(
				"inconsistent_rival_score",
				["GT I rival points must equal wins × %d" % POINTS_PER_WIN],
			)
		results_by_id[rival_id] = {
			"rival_id": rival_id,
			"points": points,
			"wins": wins,
		}

	var normalized_results: Array[Dictionary] = []
	for rival_id in canonical_ids:
		if not results_by_id.has(rival_id):
			return _rejected(
				"incomplete_rival_results_batch",
				["Missing explicit GT I result for %s" % rival_id],
			)
		normalized_results.append((results_by_id[rival_id] as Dictionary).duplicate(true))
	return {
		"status": "ready",
		"reason": "",
		"errors": [],
		"normalized_results": normalized_results.duplicate(true),
		"required_rival_results": REQUIRED_RIVAL_RESULTS,
		"score_source": "explicit_external_results",
		"generated_scores": false,
	}


func register_explicit_results(results: Array) -> Dictionary:
	var validation := validate_explicit_results(results)
	if validation.get("status") != "ready":
		return validation
	var summary := TournamentManager.get_gt1_summary()
	if int(summary.get("rival_results_registered", 0)) != 0:
		return _rejected(
			"rival_results_already_registered",
			[
				"GT I rival results provider will not overwrite or mix previously registered results",
			],
		)

	var registered_results: Array[Dictionary] = []
	var standings_resolution: Dictionary = {}
	for raw_result in validation.get("normalized_results", []) as Array:
		var entry := raw_result as Dictionary
		var registered: Dictionary = (
			_registry
			. register_result(
				str(entry.get("rival_id", "")),
				int(entry.get("points", 0)),
				int(entry.get("wins", 0)),
			)
		)
		if registered.get("status") != "registered":
			return _rejected(
				"rival_result_registry_rejected_batch",
				registered.get("errors", []) as Array,
			)
		registered_results.append(registered.duplicate(true))
		standings_resolution = (registered.get("standings_resolution", {}) as Dictionary).duplicate(
			true
		)
	return {
		"status": "registered",
		"reason": "",
		"errors": [],
		"registered_count": registered_results.size(),
		"registered_results": registered_results.duplicate(true),
		"standings_resolution": standings_resolution.duplicate(true),
		"score_source": "explicit_external_results",
		"generated_scores": false,
		"registration_authority": "gt1_rival_result_registry",
		"standings_authority": "TournamentManager",
		"save_version_change_required": false,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"provider_authority": "gt1_rival_results_provider",
		"input_source": "explicit_external_results",
		"registration_authority": "gt1_rival_result_registry",
		"standings_authority": "TournamentManager",
		"canonical_rival_source": "DataRepository.rival_ludi",
		"required_rival_results": REQUIRED_RIVAL_RESULTS,
		"points_per_win": POINTS_PER_WIN,
		"max_points": MAX_POINTS,
		"max_wins": MAX_WINS,
		"full_batch_prevalidation_required": true,
		"partial_batch_allowed": false,
		"existing_result_overwrite_allowed": false,
		"generated_scores_allowed": false,
		"random_scores_allowed": false,
		"legacy_rival_manager_is_score_authority": false,
		"save_version_change_required": false,
	}


func _is_integral_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return float(value) == float(int(value))


func _rejected(reason: String, errors: Array) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"normalized_results": [],
		"registered_count": 0,
		"registered_results": [],
		"standings_resolution": {},
		"score_source": "explicit_external_results",
		"generated_scores": false,
		"save_version_change_required": false,
	}
