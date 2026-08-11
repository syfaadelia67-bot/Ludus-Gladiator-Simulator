extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := FileAccess.get_file_as_string("res://scripts/combat/gt1_month_16_host.gd")
	var arena_runtime := FileAccess.get_file_as_string(
		"res://scripts/ui/combat_v1_arena_runtime.gd"
	)
	var combat_runtime := FileAccess.get_file_as_string(
		"res://scripts/combat/gt1_combat_runtime.gd"
	)
	var roster_contract := FileAccess.get_file_as_string(
		"res://scripts/combat/gt1_roster_selection_contract.gd"
	)
	var beast_contract := FileAccess.get_file_as_string(
		"res://scripts/combat/gt1_beast_readiness_contract.gd"
	)
	var beast_adapter := FileAccess.get_file_as_string(
		"res://scripts/combat/combat_beast_fighter_adapter.gd"
	)
	var action_policy := FileAccess.get_file_as_string(
		"res://scripts/combat/combat_fighter_action_policy.gd"
	)
	var rival_catalog := FileAccess.get_file_as_string("res://data/rival_combat_v1_snapshots.json")

	assert(host.contains("const MONTH := 16"))
	assert(host.contains("const BOUT_COUNT := 3"))
	assert(host.contains("one_explicit_available_gladiator_per_independent_bout"))
	assert(host.contains('"independent_bouts": true'))
	assert(host.contains('"carryover": []'))
	assert(host.contains('"beasts_allowed_by_design": true'))
	assert(host.contains("gt1_beast_readiness_contract"))
	assert(host.contains('"human_selection_remains_available": true'))
	assert(host.contains('"manual_beast_snapshot_allowed": false'))
	assert(host.contains('"invent_beast_stats_allowed": false'))
	assert(host.contains('"max_points": 9'))
	assert(host.contains('"rival_generation_allowed": false'))
	assert(host.contains("prepare_beast_request"))
	assert(host.contains("build_from_beast_id"))
	assert(host.contains("start_encounter_from_live_roster"))

	assert(arena_runtime.contains("GT1Month16HostScript"))
	assert(arena_runtime.contains("start_month_16_human_session"))
	assert(arena_runtime.contains("prepare_month_16_human_request"))
	assert(arena_runtime.contains("start_month_16_beast_session"))
	assert(arena_runtime.contains("prepare_month_16_beast_request"))
	assert(arena_runtime.contains("get_month_16_beast_readiness"))
	assert(arena_runtime.contains('"month_16_host": "gt1_month_16_host"'))
	assert(arena_runtime.contains('"month_16_beast_selection_authority": "combat_beast_fighter_adapter"'))

	assert(combat_runtime.contains("if month in [13, 20]:"))
	assert(combat_runtime.contains('"month_16"'))
	assert(combat_runtime.contains('"carryover": []'))
	assert(roster_contract.contains("month_16_current_selection"))
	assert(roster_contract.contains("human_or_canonical_beast_opponents"))
	assert(roster_contract.contains("combat_beast_fighter_adapter"))
	assert(beast_contract.contains('"month_16_allows_beasts": true'))
	assert(beast_contract.contains('"fallback_to_human_stats_allowed": false'))
	assert(beast_adapter.contains('"entity_type": "beast"'))
	assert(beast_adapter.contains('"equipment_power": 0'))
	assert(beast_adapter.contains('"equipment_defense": 0'))
	assert(action_policy.contains('"block", "parry"'))
	assert(action_policy.contains('"beast_block_allowed": false'))
	assert(action_policy.contains('"beast_parry_allowed": false'))
	_assert_canonical_rival_catalog(rival_catalog)

	print("GT I Month XVI Arena host contract: OK")
	get_tree().quit(0)


func _assert_canonical_rival_catalog(rival_catalog: String) -> void:
	assert(rival_catalog.strip_edges() != "[]")
	assert(rival_catalog.contains('"rival_ludus_id": "cassianus"'))
	assert(rival_catalog.contains('"id": "rival_heavy"'))
	assert(rival_catalog.contains('"id": "rival_agile"'))
	assert(rival_catalog.contains('"id": "rival_technical"'))
