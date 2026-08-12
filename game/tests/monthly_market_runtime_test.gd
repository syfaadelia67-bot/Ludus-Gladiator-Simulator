extends Node


func _ready() -> void:
	_assert_active_monthly_sources()
	_assert_runtime_is_fail_closed()
	print("Monthly market runtime and persistence contract: OK")
	get_tree().quit(0)


func _assert_active_monthly_sources() -> void:
	var manager := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
	var screen := FileAccess.get_file_as_string("res://scripts/ui/market_screen_monthly.gd")
	var scene := FileAccess.get_file_as_string("res://scenes/MarketScreen.tscn")
	var save := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")
	var reset := FileAccess.get_file_as_string("res://scripts/core/new_campaign_coordinator.gd")

	assert(manager.contains("GameState.month_advanced.connect"))
	assert(not manager.contains("GameState.week_advanced.connect"))
	assert(manager.contains("can_generate_procedural_recruits"))
	assert(manager.contains("can_generate_procedural_equipment"))
	assert(manager.contains("func reset_for_new_campaign()"))
	assert(manager.contains("var last_market_rotation_month: int = 1"))

	var month_handler_start := manager.find("func _on_month_advanced")
	var month_handler_end := manager.find(
		"\n\nfunc get_market_rotation_policy", month_handler_start
	)
	assert(month_handler_start >= 0 and month_handler_end > month_handler_start)
	var month_handler := manager.substr(
		month_handler_start, month_handler_end - month_handler_start
	)
	assert(not month_handler.contains("refresh_market("))
	assert(not month_handler.contains("refresh_equipment_market("))

	assert(screen.contains("GameState.month_advanced.connect"))
	assert(not screen.contains("GameState.week_advanced.connect"))
	assert(not screen.to_lower().contains("semana"))
	assert(screen.contains("RENOVACIÓN MANUAL · PENDIENTE"))
	assert(scene.contains("res://scripts/ui/market_screen_monthly.gd"))
	assert(not scene.to_lower().contains("semana"))
	assert(not scene.contains("· 100"))

	assert(save.contains('market_data["last_market_rotation_month"]'))
	assert(save.contains('market_data["last_auto_refresh_month"]'))
	assert(save.contains('market_data["last_auto_refresh_week"]'))
	assert(reset.contains('"last_market_rotation_month": 1'))
	assert(reset.contains('"equipment_offers": []'))
	assert(reset.contains('"equipment_offer_serial": 0'))


func _assert_runtime_is_fail_closed() -> void:
	CampaignManager.campaign_over = false
	GameState.day = 1
	GameState.denarii = 650
	MarketManager.reset_for_new_campaign()

	var policy := MarketManager.get_market_rotation_policy()
	assert(policy.get("month_native") == true)
	assert(policy.get("authored_unique_sync_enabled") == true)
	assert(int(policy.get("authored_unique_sync_cadence_months", 0)) == 1)
	assert(policy.get("procedural_auto_rotation_enabled") == false)
	assert(policy.get("manual_equipment_refresh_enabled") == false)
	assert(policy.get("procedural_recruit_generation_enabled") == false)
	assert(policy.get("procedural_equipment_generation_enabled") == false)
	assert(MarketManager.last_market_rotation_month == 1)
	assert(MarketManager.get_next_auto_refresh_month() == -1)
	assert(MarketManager.get_months_until_auto_refresh() == -1)
	assert(MarketManager.get_manual_equipment_refresh_cost() == -1)
	assert(MarketManager._serial == 0)
	assert(MarketManager._equipment_offer_serial == 0)
	assert(MarketManager.get_equipment_offers().is_empty())

	var denarii_before := GameState.denarii
	assert(not MarketManager.refresh_equipment_market(true))
	assert(GameState.denarii == denarii_before)

	var fighter_serial_before := MarketManager._serial
	var equipment_serial_before := MarketManager._equipment_offer_serial
	MarketManager._on_month_advanced(2)
	assert(MarketManager._serial == fighter_serial_before)
	assert(MarketManager._equipment_offer_serial == equipment_serial_before)
	assert(MarketManager.get_equipment_offers().is_empty())
