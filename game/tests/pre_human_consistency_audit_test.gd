extends Node


func _ready() -> void:
	var history := FileAccess.get_file_as_string(
		"res://scripts/systems/combat_history_manager_weekly.gd"
	)
	var bridge := FileAccess.get_file_as_string(
		"res://scripts/combat/gt1_combat_intent_bridge.gd"
	)
	var closure := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_closure_presenter.gd"
	)
	var project := FileAccess.get_file_as_string("res://project.godot")

	assert(project.contains('CombatHistoryManager="*res://scripts/systems/combat_history_manager_weekly.gd"'))

	assert(history.contains("func _ready() -> void:"))
	assert(history.contains("func register_gt1_bout("))
	assert(history.contains('"authority": "combat_history_observer_only"'))
	assert(history.contains('"legacy_combat_manager_subscription": false'))
	assert(history.contains('entry["month"] = month'))
	assert(history.contains('entry["week"] = month'))
	assert(history.contains('entry["day"] = month'))
	assert(history.contains('"result_authority": "combat_simulator"'))
	assert(history.contains('"scoring_authority": "TournamentManager"'))
	assert(not history.contains("_connect_combat_manager"))
	assert(not history.contains("CombatManager.combat_finished"))

	assert(bridge.contains("_register_completed_bout_history(session, next)"))
	assert(bridge.contains("CombatHistoryManager.register_gt1_bout("))
	assert(bridge.contains("next_completed != previous_completed + 1"))
	assert(bridge.contains('"combat_history_authority": "observer_only_after_completed_bout"'))
	assert(bridge.contains('"legacy_combat_history_source_allowed": false'))

	assert(closure.contains('summary.get("recovery", {})'))
	assert(closure.contains('recovery.get("injury_auto_recovery_active", false)'))
	assert(closure.contains("La recuperación automática se procesa al cierre de cada mes."))
	assert(not closure.contains("La recuperación automática permanece pendiente de balance mensual."))

	print("Pre-human consistency audit: OK")
	get_tree().quit(0)
