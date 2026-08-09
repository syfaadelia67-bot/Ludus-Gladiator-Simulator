extends "res://scripts/systems/relationship_manager.gd"


func _ready() -> void:
	RosterManager.roster_changed.connect(_ensure_all_pairs)
	CombatManager.combat_finished.connect(_on_combat_finished)
	GameState.month_advanced.connect(_on_month_advanced)
	call_deferred("_ensure_all_pairs")


func _on_month_advanced(month: int) -> void:
	_reset_interventions_for_week(month)
	relationships_changed.emit()


func process_month(totals: Dictionary) -> Array:
	# The inherited social kernel is evaluated once for the canonical month.
	# GameState.get_week() is a Save-v14 alias of get_month(), so it cannot create
	# an additional weekly simulation tick.
	return super.process_day(totals)


func process_day(totals: Dictionary) -> Array:
	# Legacy caller adapter only.
	return process_month(totals)
