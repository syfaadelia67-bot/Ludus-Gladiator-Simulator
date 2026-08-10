extends Node

const MONTHLY_ROSTER_WORK_POLICY = preload("res://scripts/systems/monthly_roster_work_policy.gd")


func _ready() -> void:
	var contract := MONTHLY_ROSTER_WORK_POLICY.get_contract()
	assert(
		contract.get("status") == "pending_frozen_monthly_work_training_fatigue_recovery_balance"
	)
	assert(contract.get("work_outputs_enabled") == false)
	assert(contract.get("training_progress_enabled") == false)
	assert(contract.get("fatigue_mutation_enabled") == false)
	assert(contract.get("injury_auto_recovery_enabled") == false)
	assert(contract.get("injury_treatment_enabled") == false)
	assert(contract.get("fatigue_combat_availability_enabled") == false)
	assert(contract.get("legacy_daily_formula_allowed") == false)
	assert(contract.get("legacy_weekly_formula_allowed") == false)
	assert(contract.get("invent_monthly_values_allowed") == false)
	assert(contract.get("save_version_change_required") == false)
	print("Monthly roster work policy contract: OK")
	get_tree().quit(0)
