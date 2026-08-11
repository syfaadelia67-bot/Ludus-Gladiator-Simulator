extends RefCounted

const STATUS := "frozen_demo_estate_runtime_boundary"
const DEMO_BUILDING_IDS: Array[String] = [
	"barracks",
	"beast_area",
	"dominus_house",
	"forge",
	"infirmary",
	"mine",
	"training_yard",
]

const ACTIVE_STRUCTURAL_EFFECTS := {
	"dominus_house": "campaign_access",
	"barracks": "roster_capacity",
	"forge": "forge_level",
	"beast_area": "owned_beast_registry_access",
}

const PENDING_BALANCE_EFFECTS := {
	"training_yard": "training_gain_fatigue_and_injury_balance",
	"infirmary": "recovery_speed_and_treatment_balance",
	"mine": "monthly_production_balance",
	"beast_area": "beast_capacity_balance",
}


static func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"demo_building_ids": DEMO_BUILDING_IDS.duplicate(),
		"demo_max_level": 3,
		"full_game_max_level": 10,
		"active_structural_effects": ACTIVE_STRUCTURAL_EFFECTS.duplicate(true),
		"pending_balance_effects": PENDING_BALANCE_EFFECTS.duplicate(true),
		"training_numeric_effect_enabled": false,
		"recovery_numeric_effect_enabled": false,
		"mine_numeric_effect_enabled": false,
		"beast_capacity_limit_enabled": false,
		"owned_beast_registry_access_enabled": true,
		"invent_missing_balance_allowed": false,
	}


static func is_demo_building(building_id: String) -> bool:
	return DEMO_BUILDING_IDS.has(building_id)


static func get_effect_status(building_id: String) -> Dictionary:
	if not is_demo_building(building_id):
		return {
			"status": "full_game_only",
			"structural_effect_active": false,
			"numeric_balance_ready": false,
		}
	var structural_effect := str(ACTIVE_STRUCTURAL_EFFECTS.get(building_id, ""))
	var pending_effect := str(PENDING_BALANCE_EFFECTS.get(building_id, ""))
	return {
		"status": "active" if pending_effect.is_empty() else "partial_pending_balance",
		"structural_effect_active": not structural_effect.is_empty(),
		"structural_effect": structural_effect,
		"numeric_balance_ready": pending_effect.is_empty(),
		"pending_balance_effect": pending_effect,
	}


static func can_apply_training_numeric_effect() -> bool:
	return false


static func can_apply_recovery_numeric_effect() -> bool:
	return false


static func can_apply_mine_numeric_effect() -> bool:
	return false


static func can_enforce_beast_capacity() -> bool:
	return false