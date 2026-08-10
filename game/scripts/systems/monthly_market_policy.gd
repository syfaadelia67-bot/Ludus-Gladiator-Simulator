extends RefCounted

# Parte 3 owns the market authority boundary without inventing balance.
# Rotation cadence, manual-refresh pricing and procedural generation remain
# fail-closed until their monthly rules are explicitly frozen.
const STATUS := "pending_frozen_market_balance"
const AUTO_ROTATION_ENABLED := false
const MANUAL_EQUIPMENT_REFRESH_ENABLED := false
const PROCEDURAL_RECRUIT_GENERATION_ENABLED := false
const PROCEDURAL_EQUIPMENT_GENERATION_ENABLED := false


func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"month_native": true,
		"auto_rotation_enabled": AUTO_ROTATION_ENABLED,
		"auto_rotation_cadence_months": null,
		"manual_equipment_refresh_enabled": MANUAL_EQUIPMENT_REFRESH_ENABLED,
		"manual_equipment_refresh_cost": null,
		"procedural_recruit_generation_enabled": PROCEDURAL_RECRUIT_GENERATION_ENABLED,
		"procedural_equipment_generation_enabled": PROCEDURAL_EQUIPMENT_GENERATION_ENABLED,
		"legacy_three_turn_cadence_is_authoritative": false,
		"legacy_equipment_refresh_cost_is_authoritative": false,
		"invent_missing_balance_allowed": false,
	}


func can_auto_rotate(_month: int) -> bool:
	return AUTO_ROTATION_ENABLED


func can_manual_refresh_equipment() -> bool:
	return MANUAL_EQUIPMENT_REFRESH_ENABLED


func can_generate_procedural_recruits() -> bool:
	return PROCEDURAL_RECRUIT_GENERATION_ENABLED


func can_generate_procedural_equipment() -> bool:
	return PROCEDURAL_EQUIPMENT_GENERATION_ENABLED
