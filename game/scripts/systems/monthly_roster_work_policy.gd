extends RefCounted

const STATUS := "frozen"
const MIGRATION_MODE := "one_legacy_turn_equals_one_monthly_turn"

const WORK_OUTPUTS_ENABLED := true
const TRAINING_PROGRESS_ENABLED := true
const FATIGUE_MUTATION_ENABLED := true
const INJURY_AUTO_RECOVERY_ENABLED := true
const INJURY_TREATMENT_ENABLED := true
const FATIGUE_COMBAT_AVAILABILITY_ENABLED := true

const MINING_FATIGUE := 8
const SECURITY_FATIGUE := 4
const ESPIONAGE_FATIGUE := 6
const TRAINING_FATIGUE := 7
const IDLE_FATIGUE_RECOVERY := 6
const INJURY_FATIGUE_RECOVERY := 10
const IDLE_MORALE_RECOVERY := 2
const INJURY_MORALE_RECOVERY := 3
const FATIGUE_MORALE_DIVISOR := 25
const FATIGUE_COMBAT_LIMIT := 90
const SLAVE_PROMOTION_TRAINING_THRESHOLD := 100

const BASIC_TREATMENT_COST := 45
const BASIC_TREATMENT_RECOVERY := 1
const INTENSIVE_TREATMENT_COST := 95
const INTENSIVE_TREATMENT_RECOVERY := 2
const SPECIALIST_TREATMENT_COST := 180
const SPECIALIST_TREATMENT_RECOVERY := 3
const INFIRMARY_DISCOUNT_PER_LEVEL := 0.10
const INFIRMARY_MAX_DISCOUNT := 0.30


static func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"authority": "monthly_roster_work_policy",
		"period": "month",
		"process_frequency": "exactly_once_per_closed_month",
		"migration_mode": MIGRATION_MODE,
		"work_outputs_enabled": WORK_OUTPUTS_ENABLED,
		"training_progress_enabled": TRAINING_PROGRESS_ENABLED,
		"fatigue_mutation_enabled": FATIGUE_MUTATION_ENABLED,
		"injury_auto_recovery_enabled": INJURY_AUTO_RECOVERY_ENABLED,
		"injury_treatment_enabled": INJURY_TREATMENT_ENABLED,
		"fatigue_combat_availability_enabled": FATIGUE_COMBAT_AVAILABILITY_ENABLED,
		"mining_fatigue": MINING_FATIGUE,
		"security_fatigue": SECURITY_FATIGUE,
		"espionage_fatigue": ESPIONAGE_FATIGUE,
		"training_fatigue": TRAINING_FATIGUE,
		"idle_fatigue_recovery": IDLE_FATIGUE_RECOVERY,
		"injury_fatigue_recovery": INJURY_FATIGUE_RECOVERY,
		"fatigue_combat_limit": FATIGUE_COMBAT_LIMIT,
		"slave_promotion_training_threshold": SLAVE_PROMOTION_TRAINING_THRESHOLD,
		"treatment_costs":
		{
			"basic": BASIC_TREATMENT_COST,
			"intensive": INTENSIVE_TREATMENT_COST,
			"specialist": SPECIALIST_TREATMENT_COST,
		},
		"treatment_recovery_months":
		{
			"basic": BASIC_TREATMENT_RECOVERY,
			"intensive": INTENSIVE_TREATMENT_RECOVERY,
			"specialist": SPECIALIST_TREATMENT_RECOVERY,
		},
		"legacy_daily_formula_allowed": false,
		"legacy_weekly_formula_allowed": false,
		"legacy_values_scaled_for_months": false,
		"invent_monthly_values_allowed": false,
		"save_version_change_required": false,
	}
