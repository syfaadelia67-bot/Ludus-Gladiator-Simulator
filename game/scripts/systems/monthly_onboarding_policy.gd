extends RefCounted

const STEP_IDS: Array[String] = [
	"initial_gladiator",
	"inspect_roster",
	"assign_work",
	"inspect_finca",
	"inspect_equipment",
	"close_month",
	"gt1_preparation",
]
const GT1_MONTHS: Array[int] = [13, 16, 20]
const LEGACY_OBJECTIVE_MIGRATIONS := {
	"advance_week": "close_month",
}


func get_steps() -> Array[Dictionary]:
	return [
		{
			"id": "initial_gladiator",
			"title": "1. Tu primer gladiador",
			"text":
			(
				"La campaña comienza eligiendo uno de los tres candidatos iniciales. "
				+ "Los otros dos pasarán a casas rivales."
			),
			"system": "mercado",
			"objective": "Contratá al gladiador que representará a tu ludus.",
			"action": "open_system",
			"action_label": "Abrir Mercado",
		},
		{
			"id": "inspect_roster",
			"title": "2. Personal y roster",
			"text":
			(
				"En Personal revisás gladiadores y esclavos, además de moral, lealtad "
				+ "y su asignación de trabajo mensual."
			),
			"system": "barracks",
			"objective": "Abrí Personal para revisar el roster del ludus.",
			"action": "open_system",
			"action_label": "Abrir Personal",
		},
		{
			"id": "assign_work",
			"title": "3. Trabajo mensual",
			"text":
			(
				"Las asignaciones se resuelven una vez por mes. Cambiar un trabajo no "
				+ "crea días ni semanas internas adicionales."
			),
			"system": "barracks",
			"objective": "Cambiá la asignación de trabajo de una persona del ludus.",
			"action": "open_system",
			"action_label": "Gestionar trabajos",
		},
		{
			"id": "inspect_finca",
			"title": "4. La finca",
			"text":
			(
				"La finca concentra las instalaciones del ludus. En la demo hay siete "
				+ "instalaciones disponibles según su estado y nivel."
			),
			"system": "finca",
			"objective": "Volvé a la Finca para revisar sus instalaciones.",
			"action": "open_system",
			"action_label": "Abrir Finca",
		},
		{
			"id": "inspect_equipment",
			"title": "5. Equipamiento",
			"text":
			(
				"El equipamiento del gladiador se gestiona por ranuras. Sus valores de "
				+ "equipo llegan a Combat V1 como snapshots explícitos."
			),
			"system": "equipamiento",
			"objective": "Abrí Equipamiento y revisá las ranuras de tu gladiador.",
			"action": "open_system",
			"action_label": "Abrir Equipamiento",
		},
		{
			"id": "close_month",
			"title": "6. Cerrar el mes",
			"text":
			(
				"Un turno equivale a un mes. Antes de cerrarlo deben resolverse las "
				+ "decisiones pendientes y, en un mes de GT I, sus tres combates."
			),
			"system": "campana",
			"objective": "Cerrá un mes para procesar una única vez su gestión mensual.",
			"action": "wait_for_month_close",
			"action_label": "Usá Cerrar mes",
		},
		{
			"id": "gt1_preparation",
			"title": "7. Preparación para el GT I",
			"text":
			(
				"El primer Gran Torneo de Roma llega en el Mes XIII. Prepará roster y "
				+ "equipamiento con anticipación; los otros encuentros de la demo son XVI y XX."
			),
			"system": "arena",
			"objective":
			(
				"Recordá: XIII, XVI y XX son meses de GT I. Fuera de ellos no existe "
				+ "un combate obligatorio inventado por el tutorial."
			),
			"action": "acknowledge",
			"action_label": "Entendido",
		},
	]


func sanitize_completed_objectives(raw_objectives: Variant) -> Dictionary:
	var sanitized: Dictionary = {}
	if not raw_objectives is Dictionary:
		return sanitized
	var raw := raw_objectives as Dictionary
	for objective_id in STEP_IDS:
		if bool(raw.get(objective_id, false)):
			sanitized[objective_id] = true
	for legacy_id in LEGACY_OBJECTIVE_MIGRATIONS.keys():
		if not bool(raw.get(legacy_id, false)):
			continue
		var canonical_id := str(LEGACY_OBJECTIVE_MIGRATIONS[legacy_id])
		if STEP_IDS.has(canonical_id):
			sanitized[canonical_id] = true
	return sanitized


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"period": "month",
		"step_ids": STEP_IDS.duplicate(),
		"gt1_months": GT1_MONTHS.duplicate(),
		"first_gt1_month": 13,
		"turn_advance_signal": "month_advanced",
		"legacy_week_advance_allowed": false,
		"legacy_combat_completion_allowed": false,
		"mandatory_non_gt_combat_taught": false,
		"tutorial_progress_persists_in_owner_profile": true,
		"save_version_change_required": false,
	}
