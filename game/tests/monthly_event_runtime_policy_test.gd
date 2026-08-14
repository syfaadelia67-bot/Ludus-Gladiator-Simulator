extends Node

const MonthlyEventRuntimePolicyScript = preload(
	"res://scripts/systems/monthly_event_runtime_policy.gd"
)


func run() -> void:
	_test_contract_freezes_authored_monthly_timing()
	_test_unknown_weekly_timed_choice_is_blocked()
	_test_authored_timed_effect_is_migrated_one_to_one()
	_test_explicit_monthly_timed_choice_is_allowed()
	print("Monthly event runtime policy: OK")


func _test_contract_freezes_authored_monthly_timing() -> void:
	var policy = MonthlyEventRuntimePolicyScript.new()
	var contract: Dictionary = policy.get_contract()
	var event_rules := contract.get("event_rules", {}) as Dictionary
	var timed_effect_months := contract.get("timed_effect_months", {}) as Dictionary
	assert(contract.get("status") == "frozen")
	assert(contract.get("authority") == "monthly_event_runtime_policy")
	assert(contract.get("period") == "month")
	assert(contract.get("process_frequency") == "exactly_once_per_month")
	assert(contract.get("migration_mode") == "one_legacy_turn_equals_one_monthly_turn")
	assert(int(contract.get("authored_event_count", 0)) == 8)
	assert(contract.get("authored_random_event_generation_enabled") == true)
	assert(contract.get("monthly_cooldown_tick_enabled") == true)
	assert(contract.get("monthly_timed_effect_tick_enabled") == true)
	assert(int(contract.get("chain_followup_delay_months", 0)) == 1)
	assert(int((event_rules.get("grain_shortage", {}) as Dictionary).get("weight", 0)) == 18)
	assert(
		int((event_rules.get("grain_shortage", {}) as Dictionary).get("cooldown_months", 0)) == 3
	)
	assert(
		int((event_rules.get("patron_invitation", {}) as Dictionary).get("cooldown_months", 0)) == 5
	)
	assert(int(timed_effect_months.get("rationing", 0)) == 1)
	assert(int(timed_effect_months.get("official_hostility", 0)) == 2)
	assert(contract.get("legacy_random_event_generation_allowed") == false)
	assert(contract.get("legacy_cooldown_tick_allowed") == false)
	assert(contract.get("legacy_timed_effect_tick_allowed") == false)
	assert(contract.get("weekly_duration_to_months_conversion_allowed") == false)
	assert(contract.get("proportional_legacy_scaling_allowed") == false)
	assert(contract.get("authored_turn_value_relabel_allowed") == true)
	assert(contract.get("unknown_legacy_timed_effects_fail_closed") == true)
	assert(contract.get("invent_monthly_cadence_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _test_unknown_weekly_timed_choice_is_blocked() -> void:
	var policy = MonthlyEventRuntimePolicyScript.new()
	var choice := {"effects": {"timed": {"id": "legacy_unknown", "weeks": 2}}}
	var normalized := policy.normalize_authored_timed_effect(
		(choice.get("effects", {}) as Dictionary).get("timed", {}) as Dictionary
	)
	assert(not normalized.has("months"))
	var reason: String = policy.get_choice_timing_block_reason(choice)
	assert(not reason.is_empty())
	assert(not policy.is_canonical_monthly_effect(normalized))


func _test_authored_timed_effect_is_migrated_one_to_one() -> void:
	var policy = MonthlyEventRuntimePolicyScript.new()
	var normalized := (
		policy
		. normalize_authored_timed_effect(
			{
				"id": "official_hostility",
				"weeks": 2,
				"weekly_denarii": -40,
			}
		)
	)
	assert(int(normalized.get("months", 0)) == 2)
	assert(int(normalized.get("monthly_denarii", 0)) == -40)
	assert(not normalized.has("weeks"))
	assert(not normalized.has("weekly_denarii"))
	assert(policy.is_canonical_monthly_effect(normalized))


func _test_explicit_monthly_timed_choice_is_allowed() -> void:
	var policy = MonthlyEventRuntimePolicyScript.new()
	var choice := {"effects": {"timed": {"id": "monthly", "months": 2}}}
	assert(policy.get_choice_timing_block_reason(choice).is_empty())
	assert(policy.is_canonical_monthly_effect({"id": "monthly", "months": 2}))
