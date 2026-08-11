extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := FileAccess.get_file_as_string("res://scripts/combat/gt1_month_20_host.gd")
	var arena_runtime := FileAccess.get_file_as_string(
		"res://scripts/ui/combat_v1_arena_runtime.gd"
	)
	var combat_runtime := FileAccess.get_file_as_string(
		"res://scripts/combat/gt1_combat_runtime.gd"
	)
	var roster_contract := FileAccess.get_file_as_string(
		"res://scripts/combat/gt1_roster_selection_contract.gd"
	)
	var rival_catalog := FileAccess.get_file_as_string("res://data/rival_combat_v1_snapshots.json")

	assert(host.contains("const MONTH := 20"))
	assert(host.contains("const BOUT_COUNT := 3"))
	assert(host.contains("const TEAM_SIZE := 2"))
	assert(host.contains("same_pair_with_at_most_one_unilateral_substitution"))
	assert(host.contains('"carryover": ["current_pv", "stamina"]'))
	assert(host.contains('"substitution_limit": 1'))
	assert(host.contains('"substitute_enters_fresh": true'))
	assert(host.contains('"continuing_fighter_carries_state": true'))
	assert(host.contains('"beasts_allowed": false'))
	assert(host.contains('"max_points": 9'))
	assert(host.contains('"rival_generation_allowed": false'))
	assert(host.contains("start_encounter_from_live_roster"))

	assert(arena_runtime.contains("GT1Month20HostScript"))
	assert(arena_runtime.contains("start_month_20_session"))
	assert(arena_runtime.contains("prepare_month_20_request"))
	assert(arena_runtime.contains('"month_20_host": "gt1_month_20_host"'))

	assert(combat_runtime.contains("if month in [13, 20]:"))
	assert(combat_runtime.contains('"month_20"'))
	assert(combat_runtime.contains("same_pair_with_at_most_one_unilateral_substitution"))
	assert(combat_runtime.contains("_validate_month_20_roster"))
	assert(roster_contract.contains('"month_20"'))
	assert(roster_contract.contains("same_pair_with_at_most_one_single_fighter_substitution"))
	_assert_canonical_rival_catalog(rival_catalog)

	print("GT I Month XX Arena host contract: OK")
	get_tree().quit(0)


func _assert_canonical_rival_catalog(rival_catalog: String) -> void:
	assert(rival_catalog.strip_edges() != "[]")
	assert(rival_catalog.contains('"rival_ludus_id": "cassianus"'))
	assert(rival_catalog.contains('"id": "rival_heavy"'))
	assert(rival_catalog.contains('"id": "rival_agile"'))
	assert(rival_catalog.contains('"id": "rival_technical"'))
