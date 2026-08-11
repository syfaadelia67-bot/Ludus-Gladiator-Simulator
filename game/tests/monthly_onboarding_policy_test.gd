extends Node

const MonthlyOnboardingPolicyScript = preload("res://scripts/systems/monthly_onboarding_policy.gd")


func run() -> void:
	var policy = MonthlyOnboardingPolicyScript.new()
	var contract := policy.get_contract()
	var steps := policy.get_steps()
	var step_ids: Array[String] = []
	for step in steps:
		step_ids.append(str(step.get("id", "")))

	assert(step_ids == MonthlyOnboardingPolicyScript.STEP_IDS)
	assert(step_ids.size() == 7)
	assert(step_ids.has("initial_gladiator"))
	assert(step_ids.has("inspect_roster"))
	assert(step_ids.has("assign_work"))
	assert(step_ids.has("inspect_finca"))
	assert(step_ids.has("inspect_equipment"))
	assert(step_ids.has("close_month"))
	assert(step_ids.has("gt1_preparation"))
	assert(MonthlyOnboardingPolicyScript.GT1_MONTHS == [13, 16, 20])

	var migrated := (
		policy
		. sanitize_completed_objectives(
			{
				"initial_gladiator": true,
				"advance_week": true,
				"weekly_combat": true,
				"unknown": true,
			}
		)
	)
	assert(bool(migrated.get("initial_gladiator", false)))
	assert(bool(migrated.get("close_month", false)))
	assert(not migrated.has("advance_week"))
	assert(not migrated.has("weekly_combat"))
	assert(not migrated.has("unknown"))

	assert(str(contract.get("period", "")) == "month")
	assert(str(contract.get("turn_advance_signal", "")) == "month_advanced")
	assert(not bool(contract.get("legacy_week_advance_allowed", true)))
	assert(not bool(contract.get("legacy_combat_completion_allowed", true)))
	assert(not bool(contract.get("mandatory_non_gt_combat_taught", true)))
	assert(bool(contract.get("tutorial_progress_persists_in_owner_profile", false)))
	assert(not bool(contract.get("save_version_change_required", true)))
	print("Monthly onboarding policy tests passed")
