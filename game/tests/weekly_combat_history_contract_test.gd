extends Node


func run() -> void:
	var manager_source := FileAccess.get_file_as_string(
		"res://scripts/systems/combat_history_manager_weekly.gd"
	)
	var bridge_source := FileAccess.get_file_as_string(
		"res://scripts/combat/gt1_combat_intent_bridge.gd"
	)
	var panel_source := FileAccess.get_file_as_string("res://scripts/ui/combat_history_panel.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")

	assert(manager_source.contains("func register_gt1_bout("))
	assert(manager_source.contains('entry["month"] = month'))
	assert(manager_source.contains('entry["week"] = month'))
	assert(manager_source.contains('entry["day"] = month'))
	assert(manager_source.contains('entry.get("month", entry.get("week", entry.get("day", 1)))'))
	assert(manager_source.contains('"authority": "combat_history_observer_only"'))
	assert(manager_source.contains('"period": "month"'))
	assert(manager_source.contains('"legacy_combat_manager_subscription": false'))
	assert(not manager_source.contains("CombatManager.combat_finished"))

	assert(bridge_source.contains("_register_completed_bout_history(session, next)"))
	assert(bridge_source.contains("CombatHistoryManager"))
	assert(bridge_source.contains("register_gt1_bout("))
	assert(bridge_source.contains("next_completed != previous_completed + 1"))
	assert(bridge_source.contains('"combat_history_authority": "observer_only_after_completed_bout"'))

	assert(
		project_source.contains(
			'CombatHistoryManager="*res://scripts/systems/combat_history_manager_weekly.gd"'
		)
	)
	assert(panel_source.contains("func _entry_month"))
	assert(panel_source.contains('entry.get("month", entry.get("week", entry.get("day", 0)))'))
	assert(panel_source.contains("Mes %d"))
	assert(not panel_source.contains("Semana %d"))
	assert(not panel_source.contains("func _entry_week"))

	print("PASS: monthly combat history contract")
