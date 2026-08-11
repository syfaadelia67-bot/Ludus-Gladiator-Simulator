extends "res://scripts/systems/equipment_manager.gd"

const EQUIPMENT_RUNTIME_POLICY = preload("res://scripts/systems/equipment_runtime_policy.gd")


func get_runtime_policy() -> Dictionary:
	return EQUIPMENT_RUNTIME_POLICY.get_contract()


func get_recipe(recipe_id: String) -> Dictionary:
	var data := super.get_recipe(recipe_id)
	if data.is_empty():
		return data
	data["balance_ready"] = EQUIPMENT_RUNTIME_POLICY.can_craft()
	data["runtime_status"] = str(get_runtime_policy().get("status", ""))
	data["legacy_recipe_preview"] = false
	return data


func craft(recipe_id: String) -> bool:
	if not EQUIPMENT_RUNTIME_POLICY.can_craft():
		craft_failed.emit("La fabricación no está habilitada por la política de equipamiento.")
		return false
	return super.craft(recipe_id)


func get_combat_v1_equipped_stats(person) -> Dictionary:
	if not EQUIPMENT_RUNTIME_POLICY.can_apply_item_stats_to_combat_v1():
		return EQUIPMENT_RUNTIME_POLICY.get_combat_v1_snapshot()
	var stats := super.get_equipped_stats(person)
	return EQUIPMENT_RUNTIME_POLICY.get_combat_v1_snapshot(
		int(stats.get("power", 0)), int(stats.get("defense", 0))
	)


func get_legacy_equipped_stats(person) -> Dictionary:
	return super.get_equipped_stats(person)


func equip_item_to_slot(person_id: String, item_id: String, slot_id: String) -> bool:
	if CampaignManager.campaign_over:
		equipment_failed.emit(
			"La campaña terminó. El equipamiento está disponible solo para consulta."
		)
		return false
	return super.equip_item_to_slot(person_id, item_id, slot_id)


func unequip_equipment_slot(person_id: String, slot_id: String) -> bool:
	if CampaignManager.campaign_over:
		equipment_failed.emit(
			"La campaña terminó. El equipamiento está disponible solo para consulta."
		)
		return false
	return super.unequip_equipment_slot(person_id, slot_id)


func reconcile_inventory_ownership() -> void:
	var people_by_id: Dictionary = {}
	for person in RosterManager.get_people():
		people_by_id[str(person.id)] = person

	var claimed_slots: Dictionary = {}
	for item in inventory:
		var item_id := str(item.get("id", ""))
		var owner_id := str(item.get("equipped_by", ""))
		var slot_id := canonical_slot_id(str(item.get("equipped_slot", item.get("slot", ""))))
		if item_id.is_empty() or owner_id.is_empty():
			continue
		if not people_by_id.has(owner_id) or slot_id.is_empty() or slot_id == "mount":
			item["equipped_by"] = ""
			item["equipped_slot"] = ""
			continue
		var claim_key := "%s:%s" % [owner_id, slot_id]
		if claimed_slots.has(claim_key):
			item["equipped_by"] = ""
			item["equipped_slot"] = ""
			continue
		claimed_slots[claim_key] = item_id
		var person = people_by_id[owner_id]
		person.set_equipped_item_id(slot_id, item_id)

	inventory_changed.emit()
