extends RefCounted

const QUARANTINED_OPERATION_IDS := [
	"scout",
	"steal_plans",
	"poison_supplies",
	"bribe_guard",
	"spread_rumors",
]


func get_operation_block_reason(operation_id: String) -> String:
	if not QUARANTINED_OPERATION_IDS.has(operation_id):
		return "La operación rival seleccionada no pertenece al catálogo legacy conocido."
	return (
		"Las operaciones rivales están en cuarentena hasta congelar su cadencia, coste y riesgo "
		+ "mensuales."
	)


func get_contract() -> Dictionary:
	return {
		"status": "frozen_boundary",
		"quarantined_operation_ids": QUARANTINED_OPERATION_IDS.duplicate(),
		"legacy_operation_execution_allowed": false,
		"legacy_retaliation_rng_allowed": false,
		"legacy_gladiator_power_mutation_allowed": false,
		"gt1_combat_snapshot_mutation_allowed": false,
		"gt1_standings_mutation_allowed": false,
		"invent_monthly_costs_allowed": false,
		"invent_monthly_risk_allowed": false,
		"invent_monthly_cadence_allowed": false,
		"save_version_change_required": false,
	}
