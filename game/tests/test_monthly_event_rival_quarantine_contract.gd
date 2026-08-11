extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var events := FileAccess.get_file_as_string("res://scripts/systems/event_manager_demo.gd")
	var rivals := FileAccess.get_file_as_string("res://scripts/systems/rival_manager_weekly.gd")
	var event_policy := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_event_runtime_policy.gd"
	)
	var rival_policy := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_rival_management_policy.gd"
	)

	assert(events.contains("func process_month()"))
	assert(not events.contains("super.process_week()"))
	assert(events.contains("last_processed_month"))
	assert(events.contains("months_without_event"))
	assert(events.contains("queued_chain_month"))
	assert(events.contains("Racionar temporalmente"))
	assert(events.contains("_pick_monthly_event"))
	assert(events.contains("_tick_monthly_cooldowns"))
	assert(events.contains("normalize_authored_timed_effect"))
	assert(events.contains("get_monthly_runtime_contract"))
	assert(event_policy.contains('const STATUS := "frozen"'))
	assert(event_policy.contains('const MIGRATION_MODE := "one_legacy_turn_equals_one_monthly_turn"'))
	assert(event_policy.contains('"authored_random_event_generation_enabled": true'))
	assert(event_policy.contains('"monthly_cooldown_tick_enabled": true'))
	assert(event_policy.contains('"monthly_timed_effect_tick_enabled": true'))
	assert(event_policy.contains('"weekly_duration_to_months_conversion_allowed": false'))
	assert(event_policy.contains('"proportional_legacy_scaling_allowed": false'))
	assert(event_policy.contains('"unknown_legacy_timed_effects_fail_closed": true'))
	assert(event_policy.contains('"invent_monthly_cadence_allowed": false'))

	assert(rivals.contains("func process_month()"))
	assert(not rivals.contains("super.process_day()"))
	assert(not rivals.contains("super.run_operation"))
	assert(rivals.contains("DataRepository.get_rival_ludi()"))
	assert(rivals.contains("reconcile_canonical_rivals"))
	assert(rivals.contains('"monthly_balance_frozen": true'))
	assert(rivals.contains('"gt1_mutation_allowed": false'))
	assert(rivals.contains("get_monthly_management_contract"))
	assert(not rivals.contains("TournamentManager"))
	assert(not rivals.contains("rival_combat_v1_snapshots"))
	assert(rival_policy.contains('const STATUS := "frozen"'))
	assert(rival_policy.contains('"canonical_rival_count": 7'))
	assert(rival_policy.contains('"monthly_retaliation_rng_enabled": true'))
	assert(rival_policy.contains('"legacy_retaliation_rng_allowed": false'))
	assert(rival_policy.contains('"gladiator_power_is_combat_v1_authority": false'))
	assert(rival_policy.contains('"gt1_combat_snapshot_mutation_allowed": false'))
	assert(rival_policy.contains('"gt1_standings_mutation_allowed": false'))

	print("Monthly event and rival runtime contract: OK")
	get_tree().quit(0)
