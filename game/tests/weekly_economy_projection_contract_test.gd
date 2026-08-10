extends Node


func run() -> void:
	var economy_script := FileAccess.get_file_as_string(
		"res://scripts/systems/economy_manager_weekly.gd"
	)
	var planning_script := FileAccess.get_file_as_string(
		"res://scripts/systems/weekly_planning_controller.gd"
	)
	var audit_script := FileAccess.get_file_as_string(
		"res://scripts/systems/demo_economy_balance_controller.gd"
	)
	var panel_script := FileAccess.get_file_as_string("res://scripts/ui/economy_panel.gd")
	var project := FileAccess.get_file_as_string("res://project.godot")

	assert(economy_script.contains("func get_monthly_projection()"))
	assert(economy_script.contains("func get_monthly_fixed_costs()"))
	assert(planning_script.contains("EconomyManager.get_monthly_projection()"))
	assert(not planning_script.contains("func _get_economy_projection()"))
	assert(audit_script.contains("EconomyManager.get_monthly_projection()"))
	assert(audit_script.contains("runway_months"))
	assert(not audit_script.contains("GameState.DAYS_PER_WEEK"))
	assert(project.contains('EconomyManager="*res://scripts/systems/economy_manager_weekly.gd"'))
	assert(panel_script.contains("Costo fijo mensual"))
	assert(panel_script.contains("Ingreso mensual"))
	assert(panel_script.contains("Cuota mensual"))
	assert(panel_script.contains("Mes %d"))
	assert(not panel_script.contains("Costo fijo semanal"))
	assert(not panel_script.contains("Cuota semanal"))

	print("Monthly economy projection contract: OK")
