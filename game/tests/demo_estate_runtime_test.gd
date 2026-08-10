extends Node

const EstateManagerScript = preload("res://scripts/systems/estate_manager.gd")


func _ready() -> void:
	var previous_denarii := GameState.denarii
	var previous_campaign_over := CampaignManager.campaign_over
	var previous_capacity := RosterManager.capacity
	var estate = EstateManagerScript.new()
	estate._ensure_catalog_loaded()
	estate._ensure_level_entries()
	estate.demo_mode = true

	assert(estate.get_demo_building_ids().size() == 7)
	assert(estate.get_level("dominus_house") == 1)
	assert(estate.get_level("barracks") == 1)
	assert(estate.get_level("training_yard") == 1)
	assert(estate.get_level("forge") == 0)
	assert(estate.get_level("infirmary") == 0)
	assert(estate.get_level("mine") == 0)
	assert(estate.get_level("beast_area") == 0)
	assert(estate.get_effective_max_level("forge") == 3)
	assert(estate.get_effective_max_level("mine") == 3)
	assert(estate.get_training_multiplier() == 1.0)
	assert(estate.get_recovery_bonus() == 0)

	var mine_status := estate.get_upgrade_status("mine")
	assert(mine_status.get("can_upgrade") == false)
	assert(mine_status.get("code") == "upgrade_cost_pending")
	assert(int(mine_status.get("cost", -1)) == 0)
	assert(not estate.can_upgrade("mine"))

	CampaignManager.campaign_over = false
	GameState.denarii = 1000
	var forge_status := estate.get_upgrade_status("forge")
	assert(forge_status.get("can_upgrade") == true)
	assert(int(forge_status.get("cost", 0)) == 320)
	assert(estate.upgrade("forge"))
	assert(estate.get_level("forge") == 1)
	assert(GameState.denarii == 680)

	CampaignManager.campaign_over = true
	var campaign_over_status := estate.get_upgrade_status("forge")
	assert(campaign_over_status.get("can_upgrade") == false)
	assert(campaign_over_status.get("code") == "campaign_over")
	assert(not estate.upgrade("forge"))
	assert(estate.get_level("forge") == 1)

	assert(estate.is_locked("stable"))
	assert(estate.get_upgrade_status("stable").get("code") == "full_game_only")
	assert(estate.get_building_effect_status("training_yard").get("numeric_balance_ready") == false)
	assert(estate.get_building_effect_status("infirmary").get("numeric_balance_ready") == false)
	assert(estate.get_building_effect_status("beast_area").get("structural_effect_active") == true)

	GameState.denarii = previous_denarii
	CampaignManager.campaign_over = previous_campaign_over
	RosterManager.capacity = previous_capacity
	estate.free()
	print("Demo estate runtime: OK")
	get_tree().quit(0)
