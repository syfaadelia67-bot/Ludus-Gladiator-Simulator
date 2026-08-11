extends RefCounted

const STATUS := "frozen"
const DEMO_CATALOG_SIZE := 15
const QUALITY_MULTIPLIERS := {
	"Común": 1.0,
	"Superior": 1.15,
	"Magistral": 1.35,
}


static func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"authority": "equipment_runtime_policy",
		"catalog_scope": "demo_v1_authored_catalog",
		"demo_catalog_size": DEMO_CATALOG_SIZE,
		"structural_inventory_enabled": true,
		"equip_unequip_enabled": true,
		"save_v14_equipment_enabled": true,
		"forge_crafting_enabled": true,
		"forge_recipe_costs_ready": true,
		"forge_quality_roll_enabled": true,
		"quality_multipliers": QUALITY_MULTIPLIERS.duplicate(true),
		"item_power_defense_combat_v1_enabled": true,
		"combat_v1_stat_source": "canonical_equipped_items_after_quality_multiplier",
		"legacy_ability_tag_gating_authoritative": false,
		"catalog_breadth_ready": true,
		"full_game_catalog_frozen": false,
		"invent_missing_items_allowed": false,
		"invent_missing_balance_allowed": false,
		"save_version_change_required": false,
	}


static func can_craft() -> bool:
	return true


static func can_apply_item_stats_to_combat_v1() -> bool:
	return true


static func get_combat_v1_snapshot(power: int = 0, defense: int = 0) -> Dictionary:
	return {
		"power": maxi(0, power),
		"defense": maxi(0, defense),
		"status": STATUS,
		"balance_ready": true,
		"source": "canonical_equipped_items_after_quality_multiplier",
	}
