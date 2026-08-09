extends Node

const GT1BeastReadinessContractScript = preload(
	"res://scripts/combat/gt1_beast_readiness_contract.gd"
)


func _ready() -> void:
	DataRepository.load_all()
	var contract = GT1BeastReadinessContractScript.new()

	_test_current_canonical_beasts_are_blocked(contract)
	_test_numeric_stats_without_adapter_remain_blocked(contract)
	_test_explicit_stats_and_adapter_are_required_together(contract)
	_test_contract_forbids_invented_fallbacks(contract)

	print("GT I month XVI beast readiness contract: OK")
	get_tree().quit(0)


func _test_current_canonical_beasts_are_blocked(contract) -> void:
	var result: Dictionary = contract.evaluate(DataRepository.beasts, false)
	assert(result.get("status") == "blocked")
	assert(result.get("month_16_allows_beasts") == true)
	assert(result.get("human_selection_ready") == true)
	assert(result.get("beast_selection_ready") == false)
	assert(result.get("canonical_beast_stats_ready") == false)
	assert(result.get("runtime_beast_adapter_ready") == false)
	assert(result.get("reason") == "missing_canonical_beast_combat_stats_and_runtime_adapter")
	assert(result.get("missing_beast_ids") == [])
	var missing := result.get("missing_stats_by_beast", {}) as Dictionary
	for beast_id in ["bear", "boar", "lion"]:
		assert(missing.has(beast_id))
		var missing_stats := missing.get(beast_id, []) as Array
		for stat_id in ["FUE", "AGI", "TEC", "RES", "PV"]:
			assert(missing_stats.has(stat_id))


func _test_numeric_stats_without_adapter_remain_blocked(contract) -> void:
	var result: Dictionary = contract.evaluate(_explicit_numeric_beasts(), false)
	assert(result.get("status") == "blocked")
	assert(result.get("canonical_beast_stats_ready") == true)
	assert(result.get("runtime_beast_adapter_ready") == false)
	assert(result.get("beast_selection_ready") == false)
	assert(result.get("reason") == "missing_runtime_beast_adapter")


func _test_explicit_stats_and_adapter_are_required_together(contract) -> void:
	var result: Dictionary = contract.evaluate(_explicit_numeric_beasts(), true)
	assert(result.get("status") == "ready")
	assert(result.get("canonical_beast_stats_ready") == true)
	assert(result.get("runtime_beast_adapter_ready") == true)
	assert(result.get("beast_selection_ready") == true)
	assert(str(result.get("reason", "x")).is_empty())


func _test_contract_forbids_invented_fallbacks(contract) -> void:
	var frozen: Dictionary = contract.get_contract()
	assert(frozen.get("stats_source") == "explicit_canonical_beast_data")
	assert(frozen.get("runtime_adapter_requirement") == "explicit_ready_signal")
	assert(frozen.get("invent_stats_allowed") == false)
	assert(frozen.get("fallback_to_human_stats_allowed") == false)
	assert(frozen.get("blocked_behavior") == "human_only_selection_remains_available")


func _explicit_numeric_beasts() -> Array:
	var result: Array = []
	for beast_id in ["bear", "boar", "lion"]:
		(
			result
			. append(
				{
					"id": beast_id,
					"FUE": 1,
					"AGI": 1,
					"TEC": 1,
					"RES": 1,
					"PV": 1,
				}
			)
		)
	return result
