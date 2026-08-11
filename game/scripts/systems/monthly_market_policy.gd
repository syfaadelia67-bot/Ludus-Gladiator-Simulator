extends RefCounted

const STATUS := "frozen"
const AUTHORED_UNIQUE_SYNC_ENABLED := true
const AUTHORED_UNIQUE_SYNC_CADENCE_MONTHS := 1
const PROCEDURAL_AUTO_ROTATION_ENABLED := false
const MANUAL_EQUIPMENT_REFRESH_ENABLED := false
const PROCEDURAL_RECRUIT_GENERATION_ENABLED := false
const PROCEDURAL_EQUIPMENT_GENERATION_ENABLED := false


func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"authority": "monthly_market_policy",
		"month_native": true,
		"authored_unique_sync_enabled": AUTHORED_UNIQUE_SYNC_ENABLED,
		"authored_unique_sync_cadence_months": AUTHORED_UNIQUE_SYNC_CADENCE_MONTHS,
		"procedural_auto_rotation_enabled": PROCEDURAL_AUTO_ROTATION_ENABLED,
		"manual_equipment_refresh_enabled": MANUAL_EQUIPMENT_REFRESH_ENABLED,
		"manual_equipment_refresh_cost": null,
		"procedural_recruit_generation_enabled": PROCEDURAL_RECRUIT_GENERATION_ENABLED,
		"procedural_equipment_generation_enabled": PROCEDURAL_EQUIPMENT_GENERATION_ENABLED,
		"legacy_three_turn_cadence_is_authoritative": false,
		"legacy_equipment_refresh_cost_is_authoritative": false,
		"invent_missing_balance_allowed": false,
		"save_version_change_required": false,
	}


func should_sync_authored_unique_offers(month: int, last_sync_month: int) -> bool:
	if month < 1:
		return false
	return month != last_sync_month


func can_auto_rotate(_month: int) -> bool:
	return PROCEDURAL_AUTO_ROTATION_ENABLED


func can_manual_refresh_equipment() -> bool:
	return MANUAL_EQUIPMENT_REFRESH_ENABLED


func can_generate_procedural_recruits() -> bool:
	return PROCEDURAL_RECRUIT_GENERATION_ENABLED


func can_generate_procedural_equipment() -> bool:
	return PROCEDURAL_EQUIPMENT_GENERATION_ENABLED
