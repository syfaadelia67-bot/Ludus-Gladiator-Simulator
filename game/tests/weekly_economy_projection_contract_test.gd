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
	assert(economy_script.contains("func get_monthly_operating_cost_breakdown()"))
	assert(economy_script.contains("func get_monthly_operating_costs()"))
	assert(economy_script.contains("MonthlyOperatingCostCalculatorScript.new()"))
	assert(economy_script.contains('"Costos operativos mensuales"'))
	assert(economy_script.contains("last_processed_month"))
	assert(economy_script.contains('"duplicate_call_ignored"'))
	assert(economy_script.contains("func process_week()"))
	assert(economy_script.contains("func process_day()"))
	assert(economy_script.count("return process_month()") >= 2)
	assert(not economy_script.contains("super.process_day()"))
	assert(not economy_script.contains("_calculate_maintenance()"))
	assert(not economy_script.contains("_calculate_wages()"))
	assert(economy_script.contains('"beast_count_source_ready": false'))
	assert(not economy_script.contains("DataRepository.beasts.size()"))

	assert(planning_script.contains("EconomyManager.get_monthly_projection()"))
	assert(not planning_script.contains("func _get_economy_projection()"))
	assert(audit_script.contains("EconomyManager.get_monthly_projection()"))
	assert(audit_script.contains("runway_months"))
	assert(not audit_script.contains("GameState.DAYS_PER_WEEK"))
	assert(project.contains('EconomyManager="*res://scripts/systems/economy_manager_weekly.gd"'))
	assert(panel_script.contains("Costo operativo mensual"))
	assert(panel_script.contains("Base: %d | Esclavos: %d | Gladiadores: %d | Bestias: %d"))
	assert(panel_script.contains("Ingreso mensual"))
	assert(panel_script.contains("Cuota mensual"))
	assert(panel_script.contains("Mes %d"))
	assert(not panel_script.contains("Costo fijo semanal"))
	assert(not panel_script.contains("Cuota semanal"))

	print("Canonical monthly economy projection contract: OK")
