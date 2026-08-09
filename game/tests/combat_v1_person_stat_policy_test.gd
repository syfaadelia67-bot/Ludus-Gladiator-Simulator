extends Node

const CombatV1PersonStatPolicyScript = preload(
	"res://scripts/core/combat_v1_person_stat_policy.gd"
)


func run() -> void:
	var policy = CombatV1PersonStatPolicyScript.new()
	var contract: Dictionary = policy.get_contract()
	assert(contract.get("new_people_require_explicit_resistance") == true)
	assert(contract.get("derive_from_endurance") == false)
	assert(contract.get("derive_from_intelligence") == false)
	assert(contract.get("random_generation_range_frozen") == false)
	assert(policy.validate_new_person_data({"resistance": 5}).is_empty())
	assert(not policy.validate_new_person_data({}).is_empty())
	assert(not policy.validate_new_person_data({"resistance": 0}).is_empty())

	var roster_source := FileAccess.get_file_as_string("res://scripts/systems/roster_manager.gd")
	assert(roster_source.count('"resistance":5') >= 3)

	var market_source := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
	assert(
		market_source.contains('"resistance": 5'),
		"Random market people must declare RES explicitly instead of using legacy fallback"
	)

	var unique_text := FileAccess.get_file_as_string("res://data/unique_gladiators.json")
	var parsed: Variant = JSON.parse_string(unique_text)
	assert(parsed is Array)
	for raw_entry in parsed as Array:
		assert(raw_entry is Dictionary)
		var entry := raw_entry as Dictionary
		assert(entry.has("resistance"), "Every unique gladiator must declare canonical RES")
		assert(int(entry.get("resistance", 0)) >= 1)

	print("Combat V1 explicit person RES creation policy: OK")
