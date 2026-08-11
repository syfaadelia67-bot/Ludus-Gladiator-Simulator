extends Node


func run() -> void:
	var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
	var legacy_screen := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
	var active_screen := FileAccess.get_file_as_string("res://scripts/ui/finca_screen_monthly.gd")
	var buildings_text := FileAccess.get_file_as_string("res://data/buildings.json")
	var beast_scene := FileAccess.get_file_as_string("res://scenes/BeastAreaScreen.tscn")
	var beast_screen := FileAccess.get_file_as_string("res://scripts/ui/beast_area_screen.gd")
	var project := FileAccess.get_file_as_string("res://project.godot")
	var parsed: Variant = JSON.parse_string(buildings_text)

	assert(hub.contains("const BUILDING_SYSTEMS"))
	assert(hub.contains('"dominus_house": "campana"'))
	assert(hub.contains('"barracks": "barracks"'))
	assert(hub.contains('"training_yard": "barracks"'))
	assert(hub.contains('"forge": "forja"'))
	assert(hub.contains('"infirmary": "personal"'))
	assert(hub.contains('"mine": "economia"'))
	assert(hub.contains('"beast_area": "bestias"'))
	assert(hub.contains('"bestias": "res://scenes/BeastAreaScreen.tscn"'))
	assert(not hub.contains('"private_arena": "arena"'))
	assert(not hub.contains('"kitchen": "economia"'))
	assert(legacy_screen.contains("const BUILDING_LAYOUT"))
	assert(legacy_screen.contains('"id": "beast_area"'))
	assert(active_screen.contains("FincaHubController.open_building_system(selected_building_id)"))
	assert(active_screen.contains("GameState.month_advanced.connect"))
	assert(not active_screen.contains("GameState.week_advanced.connect"))

	assert(parsed is Array)
	var buildings := parsed as Array
	var demo_ids: Array[String] = []
	var full_game_ids: Array[String] = []
	for raw_entry in buildings:
		assert(raw_entry is Dictionary)
		var entry := raw_entry as Dictionary
		var building_id := str(entry.get("id", ""))
		if bool(entry.get("demo_available", false)):
			demo_ids.append(building_id)
		else:
			full_game_ids.append(building_id)
	demo_ids.sort()
	assert(
		(
			demo_ids
			== [
				"barracks",
				"beast_area",
				"dominus_house",
				"forge",
				"infirmary",
				"mine",
				"training_yard",
			]
		)
	)
	for full_game_id in ["kitchen", "private_arena", "sanctuary", "stable", "wall_and_gate"]:
		assert(full_game_ids.has(full_game_id))

	assert(beast_scene.contains('path="res://scripts/ui/beast_area_screen.gd"'))
	assert(beast_screen.contains("OwnedBeastRegistry.get_owned_beasts()"))
	assert(beast_screen.contains("stats Combat V1 de Jabalí, León y Oso ya están congeladas"))
	assert(beast_screen.contains("adapter canónico"))
	assert(not buildings_text.contains('"id": "market"'))
	assert(not project.contains("FincaBuildingNavigationController="))
	assert(not FileAccess.file_exists("res://scripts/ui/finca_building_navigation_controller.gd"))
	print("Hosted Finca seven-facility monthly navigation contract: OK")
