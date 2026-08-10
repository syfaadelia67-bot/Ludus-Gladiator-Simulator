extends RefCounted

const CHAIN_FOLLOWUP_DELAY_MONTHS := 1
const LEGACY_RANDOM_EVENT_GENERATION_ENABLED := false
const LEGACY_COOLDOWN_TICK_ENABLED := false
const LEGACY_TIMED_EFFECT_TICK_ENABLED := false


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
			"La duración de este efecto todavía usa balance semanal legacy y no tiene una "
			+ "duración mensual canónica."
		)
	if int(timed.get("months", 0)) <= 0:
		return "La duración mensual del efecto debe ser mayor que cero."
	return ""


func is_canonical_monthly_effect(effect: Dictionary) -> bool:
	return effect.has("months") and int(effect.get("months", 0)) > 0


func get_contract() -> Dictionary:
	return {
		"status": "frozen_boundary",
		"scheduler_authority": "event_manager_demo.process_month",
		"chain_followup_delay_months": CHAIN_FOLLOWUP_DELAY_MONTHS,
		"legacy_random_event_generation_allowed": LEGACY_RANDOM_EVENT_GENERATION_ENABLED,
		"legacy_cooldown_tick_allowed": LEGACY_COOLDOWN_TICK_ENABLED,
		"legacy_timed_effect_tick_allowed": LEGACY_TIMED_EFFECT_TICK_ENABLED,
		"weekly_duration_to_months_conversion_allowed": false,
		"invent_monthly_cadence_allowed": false,
		"save_version_change_required": false,
	}
