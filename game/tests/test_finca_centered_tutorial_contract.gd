extends Node


func run() -> void:
	var tutorial := FileAccess.get_file_as_string("res://scripts/ui/tutorial_controller.gd")
	var policy := FileAccess.get_file_as_string(
		"res://scripts/systems/monthly_onboarding_policy.gd"
	)
	var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

	assert(policy.contains('"system": "mercado"'))
	assert(policy.contains('"system": "barracks"'))
	assert(policy.contains('"system": "finca"'))
	assert(policy.contains('"system": "equipamiento"'))
	assert(policy.contains('"system": "arena"'))
	assert(tutorial.contains("FincaHubController.open_system"))
	assert(tutorial.contains("FincaHubController.system_opened.connect"))
	assert(tutorial.contains('"inspect_finca"'))
	assert(tutorial.contains('"inspect_equipment"'))
	assert(hub.contains('"finca": "res://scenes/FincaScreen.tscn"'))
	assert(hub.contains('"barracks": "res://scenes/BarracksScreen.tscn"'))
	assert(hub.contains('"equipamiento": "res://scenes/EquipmentScreen.tscn"'))
	assert(not tutorial.contains("GameState.week_advanced.connect"))
	assert(not tutorial.contains("CombatManager.combat_finished.connect"))
	print("Finca-centered monthly tutorial contract: OK")
