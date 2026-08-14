extends Node


func run() -> void:
	var tutorial := FileAccess.get_file_as_string("res://scripts/ui/tutorial_controller.gd")
	var policy := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_onboarding_policy.gd"
	)
	var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

	assert(tutorial.contains("FincaHubController.system_opened.connect(_on_system_opened)"))
	assert(tutorial.contains('FincaHubController.open_system(str(step.get("system", "")))'))
	assert(policy.contains('"system": "finca"'))
	assert(policy.contains('"system": "barracks"'))
	assert(policy.contains('"system": "mercado"'))
	assert(policy.contains('"system": "equipamiento"'))
	assert(policy.contains('"system": "arena"'))
	assert(policy.contains("Abrir Personal"))
	assert(not tutorial.contains('find_child("Tabs"'))
	assert(not tutorial.contains("tabs.current_tab"))
	assert(hub.contains('"barracks": "res://scenes/BarracksScreen.tscn"'))
	assert(hub.contains("func open_system(system_id: String)"))
	print("Tutorial hosted Finca hub monthly contract: OK")
