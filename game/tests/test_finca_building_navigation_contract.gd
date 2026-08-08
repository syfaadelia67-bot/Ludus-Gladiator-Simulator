extends Node


func run() -> void:
	var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
	var screen := FileAccess.get_file_as_string("res://scripts/ui/finca_screen.gd")
	var buildings_text := FileAccess.get_file_as_string("res://data/buildings.json")
	var project := FileAccess.get_file_as_string("res://project.godot")
	var parsed: Variant = JSON.parse_string(buildings_text)

	assert(hub.contains("const BUILDING_SYSTEMS"))
	assert(hub.contains('"dominus_house": "campana"'))
	assert(hub.contains('"barracks": "barracks"'))
	assert(hub.contains('"training_yard": "personal"'))
	assert(hub.contains('"forge": "forja"'))
	assert(hub.contains('"infirmary": "personal"'))
	assert(hub.contains('"mine": "economia"'))
	assert(not hub.contains('"private_arena": "arena"'))
	assert(not hub.contains('"kitchen": "economia"'))
	assert(screen.contains("const BUILDING_LAYOUT"))
	assert(screen.contains('"id": "beast_area"'))
	assert(screen.contains("button.pressed.connect(_on_hotspot_pressed.bind(building_id))"))
	assert(screen.contains("func _on_hotspot_pressed(building_id: String)"))
	assert(screen.contains("_open_building_modal()"))
	assert(screen.contains("func _open_selected_building()"))

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

	assert(not buildings_text.contains('"id": "market"'))
	assert(not project.contains("FincaBuildingNavigationController="))
	assert(not FileAccess.file_exists("res://scripts/ui/finca_building_navigation_controller.gd"))
	print("Hosted Finca seven-facility demo navigation with full-game catalog contract: OK")
