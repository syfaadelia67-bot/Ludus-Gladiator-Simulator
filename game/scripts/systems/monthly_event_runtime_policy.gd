extends RefCounted

const STATUS := "frozen"
const PERIOD := "month"
const PROCESS_FREQUENCY := "exactly_once_per_month"
const MIGRATION_MODE := "one_legacy_turn_equals_one_monthly_turn"
const CHAIN_FOLLOWUP_DELAY_MONTHS := 1

const EVENT_RULES := {
	"grain_shortage": {"weight": 18, "cooldown_months": 3},
	"wounded_veteran": {"weight": 15, "cooldown_months": 4},
	"corrupt_official": {"weight": 13, "cooldown_months": 4},
	"slave_dispute": {"weight": 18, "cooldown_months": 2},
	"merchant_offer": {"weight": 16, "cooldown_months": 3},
	"public_festival": {"weight": 11, "cooldown_months": 5},
	"rival_challenge": {"weight": 14, "cooldown_months": 3},
	"patron_invitation": {"weight": 12, "cooldown_months": 5},
}

const TIMED_EFFECT_MONTHS := {
	"rationing": 1,
	"veteran_training": 2,
	"official_favor": 2,
	"official_hostility": 2,
	"stolen_goods_risk": 1,
}


func get_choice_timing_block_reason(choice: Dictionary) -> String:
	var effects_value: Variant = choice.get("effects", {})
	if not effects_value is Dictionary:
		return ""
	var timed_value: Variant = (effects_value as Dictionary).get("timed", {})
	if not timed_value is Dictionary or (timed_value as Dictionary).is_empty():
		return ""
	var timed := timed_value as Dictionary
	if not timed.has("months"):
		return (
			"La duración de este efecto no fue reconocida como uno de los valores authored "
			+ "migrados 1:1 al turno mensual."
		)
	if int(timed.get("months", 0)) <= 0:
		return "La duración mensual del efecto debe ser mayor que cero."
	return ""


func is_canonical_monthly_effect(effect: Dictionary) -> bool:
	return effect.has("months") and int(effect.get("months", 0)) > 0


func get_event_weight(event_id: String) -> int:
	var rule := EVENT_RULES.get(event_id, {}) as Dictionary
	return maxi(0, int(rule.get("weight", 0)))


func get_event_cooldown_months(event_id: String) -> int:
	var rule := EVENT_RULES.get(event_id, {}) as Dictionary
	return maxi(0, int(rule.get("cooldown_months", 0)))


func normalize_authored_timed_effect(effect: Dictionary) -> Dictionary:
	var normalized := effect.duplicate(true)
	if normalized.has("months"):
		normalized["months"] = maxi(1, int(normalized.get("months", 1)))
		normalized.erase("weeks")
		normalized.erase("days")
		if normalized.has("weekly_denarii") and not normalized.has("monthly_denarii"):
			normalized["monthly_denarii"] = int(normalized.get("weekly_denarii", 0))
		normalized.erase("weekly_denarii")
		return normalized

	var effect_id := str(normalized.get("id", ""))
	if not TIMED_EFFECT_MONTHS.has(effect_id):
		return normalized
	var authored_turns := int(TIMED_EFFECT_MONTHS[effect_id])
	if int(normalized.get("weeks", -1)) != authored_turns:
		return normalized
	normalized["months"] = authored_turns
	normalized.erase("weeks")
	normalized.erase("days")
	if normalized.has("weekly_denarii"):
		normalized["monthly_denarii"] = int(normalized.get("weekly_denarii", 0))
		normalized.erase("weekly_denarii")
	return normalized


func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"authority": "monthly_event_runtime_policy",
		"scheduler_authority": "event_manager_demo.process_month",
		"period": PERIOD,
		"process_frequency": PROCESS_FREQUENCY,
		"migration_mode": MIGRATION_MODE,
		"authored_event_count": EVENT_RULES.size(),
		"authored_random_event_generation_enabled": true,
		"monthly_cooldown_tick_enabled": true,
		"monthly_timed_effect_tick_enabled": true,
		"chain_followup_delay_months": CHAIN_FOLLOWUP_DELAY_MONTHS,
		"event_rules": EVENT_RULES.duplicate(true),
		"timed_effect_months": TIMED_EFFECT_MONTHS.duplicate(true),
		"legacy_random_event_generation_allowed": false,
		"legacy_cooldown_tick_allowed": false,
		"legacy_timed_effect_tick_allowed": false,
		"weekly_duration_to_months_conversion_allowed": false,
		"proportional_legacy_scaling_allowed": false,
		"authored_turn_value_relabel_allowed": true,
		"unknown_legacy_timed_effects_fail_closed": true,
		"invent_monthly_cadence_allowed": false,
		"save_version_change_required": false,
	}
