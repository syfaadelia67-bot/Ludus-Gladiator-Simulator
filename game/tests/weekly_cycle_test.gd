extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_month := GameState.day
	var previous_combat_month := CombatManager.last_combat_day

	for month in range(1, 13):
		GameState.day = month
		assert(
			CombatManager.get_current_event_type() == "combat_v1_only",
			"Legacy CombatManager must never schedule a playable monthly fight",
		)
		var details: Dictionary = CombatManager.get_current_event_details()
		assert(bool(details.get("legacy_quarantined", false)))
		assert(int(details.get("team_size", -1)) == 0)
		assert(str(details.get("reward", "")) == "Sin recompensa legacy")

	GameState.day = 1
	assert(GameState.get_month() == 1, "The visible campaign must begin in month one")
	assert(GameState.get_week() == 1, "Legacy week accessor must remain a month alias")

	GameState.day = previous_month
	CombatManager.last_combat_day = previous_combat_month
	print("Canonical monthly cycle with legacy combat quarantine passed")
	get_tree().quit(0)
