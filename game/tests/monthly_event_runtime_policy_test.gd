extends Node

const MonthlyEventRuntimePolicyScript = preload(
	"res://scripts/systems/monthly_event_runtime_policy.gd"
)


func run() -> void:
	_test_contract_quarantines_weekly_timing()
	_test_weekly_timed_choice_is_blocked()
	_test_explicit_monthly_timed_choice_is_allowed()
	print("Monthly event runtime policy: OK")


func _test_contract_quarantines_weekly_timing() -> void:
	var policy = MonthlyEventRuntimePolicyScript.new()
	var contract: Dictionary = policy.get_contract()
	assert(int(contract.get("chain_followup_delay_months", 0)) == 1)
	assert(contract.get("legacy_random_event_generation_allowed") == false)
	assert(contract.get("legacy_cooldown_tick_allowed") == false)
	assert(contract.get("legacy_timed_effect_tick_allowed") == false)
	assert(contract.get("weekly_duration_to_months_conversion_allowed") == false)
	assert(contract.get("invent_monthly_cadence_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _test_weekly_timed_choice_is_blocked() -> void:
	var policy = MonthlyEventRuntimePolicyScript.new()
	var choice := {"effects": {"timed": {"id": "legacy", "weeks": 2}}}
	var reason: String = policy.get_choice_timing_block_reason(choice)
	assert(not reason.is_empty())
	assert(reason.contains("semanal legacy"))
	assert(not policy.is_canonical_monthly_effect({"id": "legacy", "weeks": 2}))


func _test_explicit_monthly_timed_choice_is_allowed() -> void:
	var policy = MonthlyEventRuntimePolicyScript.new()
	var choice := {"effects": {"timed": {"id": "monthly", "months": 2}}}
	assert(policy.get_choice_timing_block_reason(choice).is_empty())
	assert(policy.is_canonical_monthly_effect({"id": "monthly", "months": 2}))
