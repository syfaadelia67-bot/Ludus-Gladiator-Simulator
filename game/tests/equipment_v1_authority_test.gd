extends Node

const EquipmentRuntimePolicyScript = preload("res://scripts/systems/equipment_runtime_policy.gd")
const GT1LiveRosterStateBuilderScript = preload(
	"res://scripts/combat/gt1_live_roster_state_builder.gd"
)


func _ready() -> void:
	var policy := EquipmentRuntimePolicyScript.get_contract()
	assert(policy.get("status") == "pending_frozen_equipment_catalog")
	assert(policy.get("structural_inventory_enabled") == true)
	assert(policy.get("equip_unequip_enabled") == true)
	assert(policy.get("forge_crafting_enabled") == false)
	assert(policy.get("forge_quality_roll_enabled") == false)
	assert(policy.get("item_power_defense_combat_v1_enabled") == false)
	assert(policy.get("catalog_breadth_ready") == false)
	assert(policy.get("invent_missing_items_allowed") == false)
	assert(policy.get("save_version_change_required") == false)

	var combat_snapshot := EquipmentRuntimePolicyScript.get_combat_v1_snapshot()
	assert(int(combat_snapshot.get("power", -1)) == 0)
	assert(int(combat_snapshot.get("defense", -1)) == 0)
	assert(combat_snapshot.get("balance_ready") == false)

	var builder = GT1LiveRosterStateBuilderScript.new()
	var contract: Dictionary = builder.get_contract()
	assert(contract.get("equipment_source") == "EquipmentManager.get_combat_v1_equipped_stats")
	assert(contract.get("legacy_item_power_defense_allowed") == false)

	var manager_text := FileAccess.get_file_as_string(
		"res://scripts/systems/equipment_manager_monthly.gd"
	)
	assert(manager_text.contains("func craft(_recipe_id: String) -> bool:"))
	assert(manager_text.contains("func reconcile_inventory_ownership() -> void:"))
	assert(manager_text.contains("get_combat_v1_equipped_stats"))

	var project_text := FileAccess.get_file_as_string("res://project.godot")
	assert(
		project_text.contains(
			'EquipmentManager="*res://scripts/systems/equipment_manager_monthly.gd"'
		)
	)

	print("Equipment V1 authority and legacy-stat quarantine: OK")
	get_tree().quit(0)
