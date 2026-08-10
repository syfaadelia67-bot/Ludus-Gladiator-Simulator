extends SceneTree


func _initialize() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/MarketScreen.tscn")
	var screen_text := FileAccess.get_file_as_string("res://scripts/ui/market_screen_monthly.gd")
	var base_screen_text := FileAccess.get_file_as_string("res://scripts/ui/market_screen.gd")
	var market_text := FileAccess.get_file_as_string("res://scripts/systems/market_manager.gd")
	var policy_text := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_market_policy.gd"
	)
	var equipment_text := FileAccess.get_file_as_string(
		"res://scripts/systems/equipment_manager.gd"
	)
	var save_text := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")
	var hub_text := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

	for required_node in [
		"MarketScreen",
		"Landing",
		"FightersCard",
		"EquipmentCard",
		"ContentShell",
		"BackToMarketHome",
		"FightersView",
		"EquipmentView",
		"Refresh",
		"BackToFinca",
	]:
		assert(
			(
				scene_text.contains('name="%s"' % required_node)
				or scene_text.contains('name = "%s"' % required_node)
			)
		)

	assert(scene_text.count('type="TextureButton"') >= 2)
	assert(scene_text.contains("LUCHADORES"))
	assert(scene_text.contains("EQUIPAMIENTO"))
	assert(scene_text.contains("RENOVACIÓN MANUAL · PENDIENTE"))
	assert(not scene_text.contains("RENOVAR EQUIPAMIENTO · 100"))
	assert(not scene_text.to_lower().contains("semana"))
	assert(not scene_text.contains("ModeButtons"))
	assert(not scene_text.contains("TabContainer"))
	assert(scene_text.contains("res://scripts/ui/market_screen_monthly.gd"))

	assert(market_text.contains("const LEGACY_AUTO_REFRESH_TURNS := 3"))
	assert(market_text.contains("const LEGACY_EQUIPMENT_REFRESH_COST := 100"))
	assert(market_text.contains("GameState.month_advanced.connect"))
	assert(not market_text.contains("GameState.week_advanced.connect"))
	assert(market_text.contains("var last_market_rotation_month: int = 1"))
	assert(market_text.contains("func get_market_rotation_policy"))
	assert(market_text.contains("func reset_for_new_campaign"))
	assert(market_text.contains("func refresh_equipment_market"))
	assert(market_text.contains("func buy_equipment_offer"))
	assert(policy_text.contains("AUTO_ROTATION_ENABLED := false"))
	assert(policy_text.contains("MANUAL_EQUIPMENT_REFRESH_ENABLED := false"))
	assert(policy_text.contains("PROCEDURAL_RECRUIT_GENERATION_ENABLED := false"))
	assert(policy_text.contains("PROCEDURAL_EQUIPMENT_GENERATION_ENABLED := false"))
	assert(equipment_text.contains("func add_market_item"))

	assert(screen_text.contains("GameState.month_advanced.connect"))
	assert(not screen_text.contains("GameState.week_advanced.connect"))
	assert(not screen_text.to_lower().contains("semana"))
	assert(screen_text.contains('extends "res://scripts/ui/market_screen.gd"'))
	assert(base_screen_text.contains("func _show_market_home"))
	assert(screen_text.contains("func _open_fighters"))
	assert(screen_text.contains("func _open_equipment"))
	assert(screen_text.contains('active_section = "fighters"'))
	assert(screen_text.contains('active_section = "equipment"'))
	assert(screen_text.contains("content_shell.visible = true"))
	assert(screen_text.contains("MarketManager.refresh_equipment_market(true)"))

	assert(save_text.contains("last_market_rotation_month"))
	assert(save_text.contains("last_auto_refresh_week"))
	assert(hub_text.contains('"mercado": "res://scenes/MarketScreen.tscn"'))
	assert(hub_text.contains("var packed := load(scene_path) as PackedScene"))

	var packed := load("res://scenes/MarketScreen.tscn")
	var screen_script := load("res://scripts/ui/market_screen_monthly.gd")
	assert(packed is PackedScene)
	assert(screen_script != null)

	var instance := (packed as PackedScene).instantiate()
	assert(instance.get_node_or_null("Landing/Cards/FightersCard") is TextureButton)
	assert(instance.get_node_or_null("Landing/Cards/EquipmentCard") is TextureButton)
	assert(instance.get_node_or_null("ContentShell/SectionHeader/BackToMarketHome") is Button)
	assert(
		(
			instance.get_node_or_null("ContentShell/FightersView/OffersPanel/Margin/Content/List")
			is ItemList
		)
	)
	assert(
		(
			instance.get_node_or_null(
				"ContentShell/EquipmentView/OffersPanel/Margin/Content/Header/Refresh"
			)
			is Button
		)
	)
	instance.free()

	print("Market monthly fail-closed navigation and purchase stability contract: OK")
	quit()
