extends Node

func run() -> void:
    var economy_script := FileAccess.get_file_as_string("res://scripts/systems/economy_manager_weekly.gd")
    var planning_script := FileAccess.get_file_as_string("res://scripts/systems/weekly_planning_controller.gd")
    var audit_script := FileAccess.get_file_as_string("res://scripts/systems/demo_economy_balance_controller.gd")
    var panel_script := FileAccess.get_file_as_string("res://scripts/ui/economy_panel.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(economy_script.contains("func get_weekly_projection()"))
    assert(economy_script.contains("func get_weekly_fixed_costs()"))
    assert(planning_script.contains("EconomyManager.get_weekly_projection()"))
    assert(not planning_script.contains("func _get_economy_projection()"))
    assert(audit_script.contains("EconomyManager.get_weekly_projection()"))
    assert(project.contains("EconomyManager=\"*res://scripts/systems/economy_manager_weekly.gd\""))
    assert(panel_script.contains("Costo fijo semanal"))
    assert(panel_script.contains("Ingreso semanal"))
    assert(panel_script.contains("Cuota semanal"))
    assert(panel_script.contains("Semana %d"))
