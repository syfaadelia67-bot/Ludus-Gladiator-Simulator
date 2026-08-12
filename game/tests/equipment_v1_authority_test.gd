extends Node

const EquipmentRuntimePolicyScript = preload("res://scripts/systems/equipment_runtime_policy.gd")
const GT1LiveRosterStateBuilderScript = preload(
	"res://scripts/combat/gt1_live_roster_state_builder.gd"
)


func _ready() -> void:
	DataRepository.load_all()
	var policy := EquipmentRuntimePolicyScript.get_contract()
	var quality_multipliers := policy.get("quality_multipliers", {}) as Dictionary
	assert(policy.get("status") == "frozen")
	assert(policy.get("authority") == "equipment_runtime_policy")
	assert(policy.get("catalog_scope") == "demo_v1_authored_catalog")
	assert(int(policy.get("demo_catalog_size", 0)) == 15)
	assert(DataRepository.weapons.size() == 15)
	assert(policy.get("structural_inventory_enabled") == true)
	assert(policy.get("equip_unequip_enabled") == true)
	assert(policy.get("save_v14_equipment_enabled") == true)
	assert(policy.get("forge_crafting_enabled") == true)
	assert(policy.get("forge_recipe_costs_ready") == true)
	assert(policy.get("forge_quality_roll_enabled") == true)
	assert(is_equal_approx(float(quality_multipliers.get("Común", 0.0)), 1.0))
	assert(is_equal_approx(float(quality_multipliers.get("Superior", 0.0)), 1.15))
	assert(is_equal_approx(float(quality_multipliers.get("Magistral", 0.0)), 1.35))
	assert(policy.get("item_power_defense_combat_v1_enabled") == true)
	assert(
		policy.get("combat_v1_stat_source") == "canonical_equipped_items_after_quality_multiplier"
	)
	assert(policy.get("legacy_ability_tag_gating_authoritative") == false)
	assert(policy.get("catalog_breadth_ready") == true)
	assert(policy.get("full_game_catalog_frozen") == false)
	assert(policy.get("invent_missing_items_allowed") == false)
	assert(policy.get("invent_missing_balance_allowed") == false)
	assert(policy.get("save_version_change_required") == false)

	var combat_snapshot := EquipmentRuntimePolicyScript.get_combat_v1_snapshot(12, 7)
	assert(int(combat_snapshot.get("power", -1)) == 12)
	assert(int(combat_snapshot.get("defense", -1)) == 7)
	assert(combat_snapshot.get("balance_ready") == true)
	assert(combat_snapshot.get("source") == "canonical_equipped_items_after_quality_multiplier")

	var builder = GT1LiveRosterStateBuilderScript.new()
	var contract: Dictionary = builder.get_contract()
	assert(contract.get("equipment_source") == "EquipmentManager.get_combat_v1_equipped_stats")
	assert(contract.get("legacy_item_power_defense_allowed") == false)

	var manager_text := FileAccess.get_file_as_string(
		"res://scripts/systems/equipment_manager_monthly.gd"
	)
	assert(manager_text.contains("func craft(recipe_id: String) -> bool:"))
	assert(manager_text.contains("func reconcile_inventory_ownership() -> void:"))
	assert(manager_text.contains("func get_combat_v1_equipped_stats(person) -> Dictionary:"))

	var forge_text := FileAccess.get_file_as_string("res://scripts/ui/forge_screen_v1.gd")
	assert(forge_text.contains("var can_craft :="))
	assert(forge_text.contains('craft_button.text = "FABRICAR"'))
	assert(forge_text.contains("bool(data.get(\"balance_ready\", false))"))
	assert(forge_text.contains("GameState.ore >= ore_cost"))
	assert(forge_text.contains("GameState.denarii >= denarii_cost"))
	assert(not forge_text.contains("Fabricación pendiente de balance"))
	assert(not forge_text.contains("LEGACY / PENDIENTE"))
	assert(not forge_text.contains("catálogo parcial legacy"))

	var project_text := FileAccess.get_file_as_string("res://project.godot")
	assert(
		project_text.contains(
			'EquipmentManager="*res://scripts/systems/equipment_manager_monthly.gd"'
		)
	)

	print("Equipment V1 authored demo catalog and Combat V1 authority: OK")
	get_tree().quit(0)
