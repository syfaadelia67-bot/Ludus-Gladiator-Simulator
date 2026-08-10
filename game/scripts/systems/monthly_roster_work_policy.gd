extends RefCounted

## Numeric work/training/fatigue/recovery balance is intentionally disabled until
## the corresponding monthly values are frozen. This policy prevents legacy
## daily formulas from becoming monthly authority by accident.

const STATUS := "pending_frozen_monthly_work_training_fatigue_recovery_balance"

const WORK_OUTPUTS_ENABLED := false
const TRAINING_PROGRESS_ENABLED := false
const FATIGUE_MUTATION_ENABLED := false
const INJURY_AUTO_RECOVERY_ENABLED := false
const INJURY_TREATMENT_ENABLED := false
const FATIGUE_COMBAT_AVAILABILITY_ENABLED := false


static func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"work_outputs_enabled": WORK_OUTPUTS_ENABLED,
		"training_progress_enabled": TRAINING_PROGRESS_ENABLED,
		"fatigue_mutation_enabled": FATIGUE_MUTATION_ENABLED,
		"injury_auto_recovery_enabled": INJURY_AUTO_RECOVERY_ENABLED,
		"injury_treatment_enabled": INJURY_TREATMENT_ENABLED,
		"fatigue_combat_availability_enabled": FATIGUE_COMBAT_AVAILABILITY_ENABLED,
		"legacy_daily_formula_allowed": false,
		"legacy_weekly_formula_allowed": false,
		"invent_monthly_values_allowed": false,
		"save_version_change_required": false,
	}
