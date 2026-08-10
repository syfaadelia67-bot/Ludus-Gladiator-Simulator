extends "res://scripts/systems/rival_manager.gd"

signal monthly_rivalry_processed(month: int, events: Array)
# Compatibility signal only. It mirrors the same monthly result.
signal weekly_rivalry_processed(week: int, events: Array)

const MonthlyRivalManagementPolicyScript = preload(
	"res://scripts/systems/monthly_rival_management_policy.gd"
)

var _monthly_policy = MonthlyRivalManagementPolicyScript.new()


func get_operation(operation_id: String) -> Dictionary:
	var data := super.get_operation(operation_id)
	if data.is_empty():
		return data
	data["available"] = false
	data["blocked_reason"] = _monthly_policy.get_operation_block_reason(operation_id)
	data["legacy_balance_quarantined"] = true
	return data


func run_operation(rival_id: String, operation_id: String, agent_id: String = "") -> Dictionary:
	var month := GameState.get_month()
	if get_rival(rival_id).is_empty():
		var missing_rival_reason := "El rival seleccionado no existe."
		operation_failed.emit(missing_rival_reason)
		return _blocked_operation_result(
			rival_id, operation_id, agent_id, month, missing_rival_reason
		)
	if not OPERATIONS.has(operation_id):
		var missing_operation_reason := "La operación seleccionada no existe."
		operation_failed.emit(missing_operation_reason)
		return _blocked_operation_result(
			rival_id, operation_id, agent_id, month, missing_operation_reason
		)
	var reason := _monthly_policy.get_operation_block_reason(operation_id)
	operation_failed.emit(reason)
	return _blocked_operation_result(rival_id, operation_id, agent_id, month, reason)


func process_month() -> Array:
	# The inherited daily retaliation kernel uses legacy daily probability, heat
	# decay and random losses. None of those values are interpreted as monthly.
	var events: Array = []
	var month := GameState.get_month()
	monthly_rivalry_processed.emit(month, events.duplicate(true))
	weekly_rivalry_processed.emit(month, events.duplicate(true))
	return events


func process_week() -> Array:
	return process_month()


func process_day() -> Array:
	return process_month()


func get_monthly_management_contract() -> Dictionary:
	return _monthly_policy.get_contract()


func _blocked_operation_result(
	rival_id: String, operation_id: String, agent_id: String, month: int, reason: String
) -> Dictionary:
	return {
		"status": "blocked",
		"success": false,
		"reason": reason,
		"rival_id": rival_id,
		"operation_id": operation_id,
		"agent_id": agent_id,
		"month": month,
		"week": month,
		"day": month,
		"legacy_balance_quarantined": true,
		"gt1_mutation_allowed": false,
	}
