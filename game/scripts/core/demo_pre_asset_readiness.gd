extends RefCounted

const GT1BeastReadinessContractScript = preload(
	"res://scripts/combat/gt1_beast_readiness_contract.gd"
)

const PENDING_AUTHORITY_BOUNDARIES := {
	"monthly_economy_runtime":
	"Costs and beast ownership are canonical; sponsor, loan and bankruptcy balance remain pending.",
	"monthly_market_cadence":
	"Legacy cadence is quarantined; market rotation and refresh await monthly balance.",
	"monthly_roster_work_recovery":
	"Monthly authority is canonical; work, training, fatigue and recovery balance remain pending.",
	"equipment_catalog_and_forge_balance":
	(
		"Six-slot inventory, equip and Save v14 authority are canonical; final catalog breadth, "
		+ "crafting costs, quality and Combat V1 item power/defense remain pending."
	),
	"monthly_event_cadence":
	(
		"Event chains use month-native follow-up scheduling. Legacy random cadence, cooldowns and "
		+ "timed-effect durations are quarantined until monthly balance is frozen."
	),
	"monthly_rival_management":
	(
		"Legacy sabotage, espionage and retaliation RNG are quarantined. Monthly operation "
		+ "cadence, costs and risk rules still require frozen design values."
	),
	"playable_combat_v1_ui":
	(
		"Combat V1 Arena and the Month XIII/XVI/XX hosts are canonical. GT I still fails closed "
		+ "without rival snapshots, and XVI beast selection stays blocked until canonical beast "
		+ "stats and its runtime adapter are ready. Final player-facing series setup still needs "
		+ "to consume those canonical sources without placeholder opponent data."
	),
	"gt1_rival_results_provider":
	"GT I rival standings still require explicit external results without a campaign-owned provider.",
	"months_without_gt1_loop":
	(
		"Months outside XIII, XVI and XX now have an explicit management-only canonical loop and "
		+ "legacy arena schedules are quarantined. The blocker remains until optional/mandatory "
		+ "non-GT Arena opportunities and replacement objectives are frozen by design."
	),
}


func evaluate() -> Dictionary:
	var blockers: Array[Dictionary] = []
	_append_rival_snapshot_blocker(blockers)
	_append_beast_blockers(blockers)
	_append_pending_building_balance_blockers(blockers)
	_append_skill_mechanics_blocker(blockers)
	_append_authority_boundary_blockers(blockers)
	var report := _build_report(blockers)
	return {
		"status": "ready" if blockers.is_empty() else "blocked",
		"ready": blockers.is_empty(),
		"blocker_count": blockers.size(),
		"blockers": blockers.duplicate(true),
		"report": report.duplicate(true),
		"scope": "demo_months_1_to_20_pre_asset_programming_gate",
		"final_assets_allowed": blockers.is_empty(),
		"programming_complete_allowed": blockers.is_empty(),
		"save_version_change_required": false,
	}


func get_blocker_codes() -> Array[String]:
	var result: Array[String] = []
	for blocker in evaluate().get("blockers", []) as Array:
		if blocker is Dictionary:
			result.append(str((blocker as Dictionary).get("code", "")))
	result.sort()
	return result


func get_report() -> Dictionary:
	return (evaluate().get("report", {}) as Dictionary).duplicate(true)


func can_declare_programming_complete() -> bool:
	return bool(get_report().get("clear", false))


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"scope": "demo_months_1_to_20_pre_asset_programming_gate",
		"blockers_are_fail_closed": true,
		"final_assets_require_zero_blockers": true,
		"programming_complete_requires_clear_report": true,
		"report_lists_every_blocker": true,
		"legacy_combat_authority_allowed": false,
		"legacy_weekly_authority_allowed": false,
		"invent_missing_balance_allowed": false,
		"month_20_end_to_end_quality_gate": "automated_test",
		"save_version_change_required": false,
	}


func _build_report(blockers: Array[Dictionary]) -> Dictionary:
	var lines: Array[String] = []
	var design_blocked_count := 0
	var implementation_blocked_count := 0
	for blocker in blockers:
		(
			lines
			. append(
				(
					"%s · %s · %s"
					% [
						str(blocker.get("code", "")),
						str(blocker.get("category", "")),
						str(blocker.get("reason", "")),
					]
				)
			)
		)
		if bool(blocker.get("design_blocked", false)):
			design_blocked_count += 1
		else:
			implementation_blocked_count += 1
	return {
		"status": "clear" if blockers.is_empty() else "blocked",
		"clear": blockers.is_empty(),
		"blocker_count": blockers.size(),
		"design_blocked_count": design_blocked_count,
		"implementation_blocked_count": implementation_blocked_count,
		"unresolved_blockers": blockers.duplicate(true),
		"lines": lines.duplicate(),
		"programming_complete_allowed": blockers.is_empty(),
		"final_assets_allowed": blockers.is_empty(),
	}


func _append_rival_snapshot_blocker(blockers: Array[Dictionary]) -> void:
	if not DataRepository.get_rival_combat_v1_snapshots().is_empty():
		return
	(
		blockers
		. append(
			_blocker(
				"rival_combat_v1_snapshots_missing",
				"gt1_rivals",
				"Canonical rival gladiator Combat V1 snapshots are not frozen yet.",
				true,
			)
		)
	)


func _append_beast_blockers(blockers: Array[Dictionary]) -> void:
	var readiness := GT1BeastReadinessContractScript.new().evaluate(DataRepository.beasts, false)
	if readiness.get("canonical_beast_stats_ready") != true:
		(
			blockers
			. append(
				_blocker(
					"beast_combat_v1_stats_missing",
					"beasts",
					"Jabalí, León and Oso still require canonical Combat V1 stats.",
					true,
				)
			)
		)
	if readiness.get("runtime_beast_adapter_ready") != true:
		(
			blockers
			. append(
				_blocker(
					"beast_combat_v1_adapter_missing",
					"beasts",
					"The canonical beast-to-Combat-V1 runtime adapter is not implemented yet.",
					false,
				)
			)
		)


func _append_pending_building_balance_blockers(blockers: Array[Dictionary]) -> void:
	for building in DataRepository.get_buildings():
		if (
			building is Dictionary
			and bool((building as Dictionary).get("upgrade_cost_pending", false))
		):
			(
				blockers
				. append(
					_blocker(
						(
							"building_upgrade_cost_pending:%s"
							% str((building as Dictionary).get("id", ""))
						),
						"estate",
						"A demo building still has an explicitly pending upgrade cost.",
						true,
					)
				)
			)


func _append_skill_mechanics_blocker(blockers: Array[Dictionary]) -> void:
	if DataRepository.get_skills().is_empty():
		return
	(
		blockers
		. append(
			_blocker(
				"canonical_skill_mechanics_not_frozen",
				"skills",
				(
					"The 12 canonical skill identities are reconciled and authoritative, but their "
					+ "Combat V1 mechanics and progression are not frozen yet."
				),
				true,
			)
		)
	)


func _append_authority_boundary_blockers(blockers: Array[Dictionary]) -> void:
	for code in PENDING_AUTHORITY_BOUNDARIES.keys():
		(
			blockers
			. append(
				_blocker(
					str(code),
					"architecture",
					str(PENDING_AUTHORITY_BOUNDARIES[code]),
					false,
				)
			)
		)


func _blocker(code: String, category: String, reason: String, design_blocked: bool) -> Dictionary:
	return {
		"code": code,
		"category": category,
		"reason": reason,
		"design_blocked": design_blocked,
		"invent_values_allowed": false,
	}
