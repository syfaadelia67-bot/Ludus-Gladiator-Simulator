extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := FileAccess.get_file_as_string("res://scripts/combat/gt1_month_13_host.gd")
	var arena_runtime := FileAccess.get_file_as_string("res://scripts/ui/combat_v1_arena_runtime.gd")
	var combat_runtime := FileAccess.get_file_as_string("res://scripts/combat/gt1_combat_runtime.gd")
	var rival_catalog := FileAccess.get_file_as_string("res://data/rival_combat_v1_snapshots.json")

	assert(host.contains("const MONTH := 13"))
	assert(host.contains("const BOUT_COUNT := 3"))
	assert(host.contains("one_explicit_gladiator_reused_all_three_bouts"))
	assert(host.contains('"beasts_allowed": false'))
	assert(host.contains('["current_pv", "stamina"]'))
	assert(host.contains('"max_points": 9'))
	assert(host.contains('"rival_generation_allowed": false'))
	assert(host.contains("start_encounter_from_live_roster"))

	assert(arena_runtime.contains("GT1Month13HostScript"))
	assert(arena_runtime.contains("start_month_13_session"))
	assert(arena_runtime.contains("prepare_month_13_request"))
	assert(arena_runtime.contains('"month_13_host": "gt1_month_13_host"'))

	assert(combat_runtime.contains("_validate_month_13_roster"))
	assert(combat_runtime.contains("month in [13, 20]"))
	assert(combat_runtime.contains("prepare_consecutive_fight"))
	assert(combat_runtime.contains("register_grand_tournament_fight_result"))
	assert(rival_catalog.strip_edges() == "[]")

	print("GT I Month XIII Arena host contract: OK")
	get_tree().quit(0)
