extends RefCounted

const STATUS := "pending_frozen_equipment_catalog"


static func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"structural_inventory_enabled": true,
		"equip_unequip_enabled": true,
		"save_v14_equipment_enabled": true,
		"forge_crafting_enabled": false,
		"forge_recipe_costs_ready": false,
		"forge_quality_roll_enabled": false,
		"item_power_defense_combat_v1_enabled": false,
		"legacy_ability_tag_gating_authoritative": false,
		"catalog_breadth_ready": false,
		"invent_missing_items_allowed": false,
		"invent_missing_balance_allowed": false,
		"save_version_change_required": false,
	}


static func can_craft() -> bool:
	return bool(get_contract().get("forge_crafting_enabled", false))


static func can_apply_item_stats_to_combat_v1() -> bool:
	return bool(get_contract().get("item_power_defense_combat_v1_enabled", false))


static func get_combat_v1_snapshot() -> Dictionary:
	return {
		"power": 0,
		"defense": 0,
		"status": STATUS,
		"balance_ready": false,
		"source": "equipment_runtime_policy",
	}
