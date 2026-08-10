extends Node


func run() -> void:
	var catalog_text := FileAccess.get_file_as_string("res://data/buildings.json")
	var scene_text := FileAccess.get_file_as_string("res://scenes/FincaScreen.tscn")
	var legacy_controller := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
	var active_controller := FileAccess.get_file_as_string("res://scripts/ui/finca_screen_monthly.gd")
	var parsed: Variant = JSON.parse_string(catalog_text)

	assert(parsed is Array)
	var buildings := parsed as Array
	assert(buildings.size() > 7, "Full-game building catalog must extend beyond demo scope")

	var demo_count := 0
	var full_game_count := 0
	for raw_entry in buildings:
		assert(raw_entry is Dictionary)
		var entry := raw_entry as Dictionary
		assert(int(entry.get("max_level", 0)) == 10)
		if bool(entry.get("demo_available", false)):
			demo_count += 1
			assert(int(entry.get("demo_max_level", 0)) == 3)
		else:
			full_game_count += 1
			assert(int(entry.get("demo_max_level", 0)) == 0)
	assert(demo_count == 7)
	assert(full_game_count > 0)

	for building_id in [
		"dominus_house",
		"barracks",
		"training_yard",
		"forge",
		"infirmary",
		"mine",
		"beast_area",
	]:
		assert(legacy_controller.contains('"id": "%s"' % building_id))

	for full_game_id in [
		"kitchen",
		"warehouse",
		"worker_quarters",
		"wall_and_gate",
		"sanctuary",
		"private_arena",
		"stable",
	]:
		assert(catalog_text.contains('"id": "%s"' % full_game_id))
		assert(not legacy_controller.contains('"id": "%s"' % full_game_id))

	assert(active_controller.contains("BLUR_SHADER_CODE") or legacy_controller.contains("BLUR_SHADER_CODE"))
	assert(legacy_controller.contains("hint_screen_texture"))
	assert(legacy_controller.contains("textureLod"))
	assert(legacy_controller.contains("func _build_building_modal()"))
	assert(active_controller.contains("func _refresh_modal()"))
	assert(active_controller.contains("func _open_selected_building()"))
	assert(active_controller.contains("upgrade_cost_pending"))
	assert(active_controller.contains("GameState.month_advanced.connect"))
	assert(not active_controller.contains("GameState.week_advanced.connect"))
	assert(active_controller.contains("DEMO · NIVEL %d/%d · JUEGO COMPLETO 0–10"))
	assert(active_controller.contains("Abrir zona de bestias"))

	assert(scene_text.contains('[node name="QuickAccess" type="PanelContainer" parent="."]'))
	assert(scene_text.contains('path="res://scripts/ui/finca_screen_monthly.gd"'))
	assert(scene_text.contains('text = "FINCA DEL LUDUS · 7 INSTALACIONES DE DEMO"'))
	assert(scene_text.contains('text = "MES 1"'))
	assert(scene_text.contains('text = "Cerrar mes"'))
	assert(not scene_text.to_lower().contains("semana"))
	assert(
		scene_text.contains(
			'[node name="Market" type="Button" parent="QuickAccess/Margin/Center/Row"]'
		)
	)
	assert(
		scene_text.contains(
			'[node name="Arena" type="Button" parent="QuickAccess/Margin/Center/Row"]'
		)
	)
	assert(
		scene_text.contains(
			'[node name="Personal" type="Button" parent="QuickAccess/Margin/Center/Row"]'
		)
	)
	assert(scene_text.contains("custom_minimum_size = Vector2(280, 68)"))

	var packed := load("res://scenes/FincaScreen.tscn") as PackedScene
	assert(packed != null)
	var instance := packed.instantiate()
	assert(instance.get_node_or_null("Center/WorldPanel/WorldMargin/WorldArea") != null)
	assert(instance.get_node_or_null("QuickAccess/Margin/Center/Row/Market") is Button)
	assert(instance.get_node_or_null("QuickAccess/Margin/Center/Row/Arena") is Button)
	assert(instance.get_node_or_null("QuickAccess/Margin/Center/Row/Personal") is Button)
	instance.free()

	print("Finca seven-facility monthly demo modal contract: OK")
