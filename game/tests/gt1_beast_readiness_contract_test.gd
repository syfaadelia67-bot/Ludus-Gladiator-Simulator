extends Node

const GT1BeastReadinessContractScript = preload(
	"res://scripts/combat/gt1_beast_readiness_contract.gd"
)


func _ready() -> void:
	DataRepository.load_all()
	var contract = GT1BeastReadinessContractScript.new()

	_test_current_canonical_beasts_have_frozen_stats(contract)
	_test_noncanonical_numeric_profile_is_blocked(contract)
	_test_explicit_stats_and_adapter_are_required_together(contract)
	_test_contract_forbids_invented_fallbacks(contract)

	print("GT I month XVI beast readiness contract: OK")
	get_tree().quit(0)


func _test_current_canonical_beasts_have_frozen_stats(contract) -> void:
	var result: Dictionary = contract.evaluate(DataRepository.beasts, false)
	assert(result.get("status") == "blocked")
	assert(result.get("month_16_allows_beasts") == true)
	assert(result.get("human_selection_ready") == true)
	assert(result.get("beast_selection_ready") == false)
	assert(result.get("canonical_beast_stats_ready") == true)
	assert(result.get("runtime_beast_adapter_ready") == false)
	assert(result.get("reason") == "missing_runtime_beast_adapter")
	assert(result.get("missing_beast_ids") == [])
	assert((result.get("missing_stats_by_beast", {}) as Dictionary).is_empty())
	assert((result.get("invalid_stats_by_beast", {}) as Dictionary).is_empty())
	assert((result.get("mismatched_profiles", []) as Array).is_empty())
	assert((result.get("profile_errors", []) as Array).is_empty())
	_assert_profile("boar", {"FUE": 7, "AGI": 5, "TEC": 6, "RES": 6, "PV": 56, "stamina": 10})
	_assert_profile("lion", {"FUE": 8, "AGI": 9, "TEC": 8, "RES": 5, "PV": 55, "stamina": 10})
	_assert_profile("bear", {"FUE": 10, "AGI": 4, "TEC": 5, "RES": 8, "PV": 68, "stamina": 10})


func _test_noncanonical_numeric_profile_is_blocked(contract) -> void:
	var beasts := DataRepository.beasts.duplicate(true)
	for raw_beast in beasts:
		var beast := raw_beast as Dictionary
		if str(beast.get("id", "")) == "lion":
			beast["AGI"] = 8
			break
	var result: Dictionary = contract.evaluate(beasts, true)
	assert(result.get("status") == "blocked")
	assert(result.get("canonical_beast_stats_ready") == false)
	assert(result.get("runtime_beast_adapter_ready") == true)
	assert(result.get("beast_selection_ready") == false)
	assert(result.get("reason") == "missing_canonical_beast_combat_stats")
	assert((result.get("mismatched_profiles", []) as Array).has("lion"))
	assert(not (result.get("profile_errors", []) as Array).is_empty())


func _test_explicit_stats_and_adapter_are_required_together(contract) -> void:
	var result: Dictionary = contract.evaluate(DataRepository.beasts, true)
	assert(result.get("status") == "ready")
	assert(result.get("canonical_beast_stats_ready") == true)
	assert(result.get("runtime_beast_adapter_ready") == true)
	assert(result.get("beast_selection_ready") == true)
	assert(str(result.get("reason", "x")).is_empty())


func _test_contract_forbids_invented_fallbacks(contract) -> void:
	var frozen: Dictionary = contract.get_contract()
	assert(frozen.get("stats_source") == "explicit_canonical_beast_data")
	assert(frozen.get("runtime_adapter_requirement") == "explicit_ready_signal")
	assert(frozen.get("required_stamina_field") == "stamina")
	assert(frozen.get("invent_stats_allowed") == false)
	assert(frozen.get("fallback_to_human_stats_allowed") == false)
	assert(frozen.get("blocked_behavior") == "human_only_selection_remains_available")
	var profiles := frozen.get("canonical_profiles", {}) as Dictionary
	assert(profiles.size() == 3)


func _assert_profile(beast_id: String, expected: Dictionary) -> void:
	var beast: Dictionary = {}
	for raw_beast in DataRepository.beasts:
		var candidate := raw_beast as Dictionary
		if str(candidate.get("id", "")) == beast_id:
			beast = candidate
			break
	assert(not beast.is_empty())
	for value_id in ["FUE", "AGI", "TEC", "RES", "PV", "stamina"]:
		assert(float(beast.get(value_id, -1.0)) == float(expected.get(value_id, -2.0)))
