extends RefCounted

const CombatBeastFighterAdapterScript = preload(
	"res://scripts/combat/combat_beast_fighter_adapter.gd"
)
const CombatSkillRuntimeResolverScript = preload(
	"res://scripts/combat/combat_skill_runtime_resolver.gd"
)
const CanonicalSkillMechanicsContractScript = preload(
	"res://scripts/core/canonical_skill_mechanics_contract.gd"
)
const GT1BeastReadinessContractScript = preload(
	"res://scripts/combat/gt1_beast_readiness_contract.gd"
)
const GT1RivalRosterReadinessContractScript = preload(
	"res://scripts/combat/gt1_rival_roster_readiness_contract.gd"
)

const PENDING_AUTHORITY_BOUNDARIES := {
	"monthly_rival_management": "Legacy sabotage, espionage and retaliation RNG are quarantined. Monthly operation cadence, costs and risk rules still require frozen design values.",
	"months_without_gt1_loop": "Months outside XIII, XVI and XX now have an explicit management-only canonical loop and legacy arena schedules are quarantined. The blocker remains until optional/mandatory non-GT Arena opportunities and replacement objectives are frozen by design.",
}


func evaluate() -> Dictionary:
	var blockers: Array[Dictionary] = []
	_append_rival_snapshot_blocker(blockers)
	_append_rival_results_provider_blocker(blockers)
	_append_beast_blockers(blockers)
	_append_pending_building_balance_blockers(blockers)
	_append_skill_mechanics_blocker(blockers)
	_append_monthly_economy_blocker(blockers)
	_append_monthly_market_blocker(blockers)
	_append_monthly_roster_blocker(blockers)
	_append_equipment_blocker(blockers)
	_append_monthly_event_blocker(blockers)
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
		"skill_mechanics_source_fail_closed": true,
		"skill_runtime_quality_gate": "combat_skill_runtime_resolver_contract",
		"monthly_economy_quality_gate": "economy_manager_monthly_runtime_contract",
		"monthly_market_quality_gate": "market_manager_monthly_policy_contract",
		"monthly_roster_quality_gate": "roster_manager_monthly_work_policy_contract",
		"equipment_quality_gate": "equipment_runtime_policy_contract",
		"monthly_event_quality_gate": "monthly_event_runtime_policy_contract",
		"gt1_rival_results_provider_quality_gate": "campaign_owned_contract",
		"month_20_end_to_end_quality_gate": "automated_test",
		"save_version_change_required": false,
	}


func _build_report(blockers: Array[Dictionary]) -> Dictionary:
	var lines: Array[String] = []
	var design_blocked_count := 0
	var implementation_blocked_count := 0
	for blocker in blockers:
		lines.append(
			"%s · %s · %s"
			% [
				str(blocker.get("code", "")),
				str(blocker.get("category", "")),
				str(blocker.get("reason", "")),
			]
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
	var readiness := GT1RivalRosterReadinessContractScript.new().evaluate(
		DataRepository.get_rival_combat_v1_snapshots()
	)
	if readiness.get("ready") == true:
		return
	blockers.append(
		_blocker(
			"rival_combat_v1_snapshots_missing",
			"gt1_rivals",
			"Canonical rival Combat V1 roster coverage is incomplete or does not match the three frozen demo archetypes for all seven Ludi.",
			true
		)
	)


func _append_rival_results_provider_blocker(blockers: Array[Dictionary]) -> void:
	if not CampaignManager.has_method("get_gt1_rival_results_provider_contract"):
		blockers.append(
			_blocker(
				"gt1_rival_results_provider",
				"architecture",
				"CampaignManager does not expose the canonical GT I rival results provider.",
				false
			)
		)
		return
	var contract: Dictionary = CampaignManager.get_gt1_rival_results_provider_contract()
	var ready: bool = (
		contract.get("status") == "frozen"
		and contract.get("provider_authority") == "gt1_rival_results_provider"
		and contract.get("input_source") == "explicit_external_results"
		and contract.get("registration_authority") == "gt1_rival_result_registry"
		and contract.get("standings_authority") == "TournamentManager"
		and int(contract.get("required_rival_results", 0)) == 7
		and contract.get("full_batch_prevalidation_required") == true
		and contract.get("partial_batch_allowed") == false
		and contract.get("existing_result_overwrite_allowed") == false
		and contract.get("generated_scores_allowed") == false
		and contract.get("random_scores_allowed") == false
		and contract.get("legacy_rival_manager_is_score_authority") == false
		and contract.get("save_version_change_required") == false
	)
	if ready:
		return
	blockers.append(
		_blocker(
			"gt1_rival_results_provider",
			"architecture",
			"GT I rival standings require a campaign-owned, explicit external-results provider that cannot generate, randomize, partially register or overwrite rival scores.",
			false
		)
	)


func _append_beast_blockers(blockers: Array[Dictionary]) -> void:
	var adapter_audit := CombatBeastFighterAdapterScript.new().audit_catalog(DataRepository.beasts)
	var readiness := GT1BeastReadinessContractScript.new().evaluate(
		DataRepository.beasts, adapter_audit.get("ready") == true
	)
	if readiness.get("canonical_beast_stats_ready") != true:
		blockers.append(
			_blocker(
				"beast_combat_v1_stats_missing",
				"beasts",
				"Jabalí, León and Oso still require canonical Combat V1 stats.",
				true
			)
		)
	if readiness.get("runtime_beast_adapter_ready") != true:
		blockers.append(
			_blocker(
				"beast_combat_v1_adapter_missing",
				"beasts",
				"The canonical beast-to-Combat-V1 runtime adapter is not ready.",
				false
			)
		)


func _append_pending_building_balance_blockers(blockers: Array[Dictionary]) -> void:
	for building in DataRepository.get_buildings():
		if (
			building is Dictionary
			and bool((building as Dictionary).get("upgrade_cost_pending", false))
		):
			blockers.append(
				_blocker(
					"building_upgrade_cost_pending:%s"
					% str((building as Dictionary).get("id", "")),
					"estate",
					"A demo building still has an explicitly pending upgrade cost.",
					true
				)
			)


func _append_skill_mechanics_blocker(blockers: Array[Dictionary]) -> void:
	var runtime_contract := CombatSkillRuntimeResolverScript.new().get_contract()
	var runtime_ready := (
		runtime_contract.get("status") == "frozen"
		and runtime_contract.get("authority") == "skill_intent_translation_only"
		and runtime_contract.get("damage_authority") == "combat_simulator"
		and runtime_contract.get("ko_authority") == "combat_simulator"
		and runtime_contract.get("winner_authority") == "combat_simulator"
		and runtime_contract.get("beast_skills_allowed") == false
		and runtime_contract.get("save_version_change_required") == false
	)
	var readiness := CanonicalSkillMechanicsContractScript.new().evaluate(
		DataRepository.get_skills(), DataRepository.get_skill_mechanics_v1(), runtime_ready
	)
	if readiness.get("ready") == true:
		return
	var design_ready := bool(readiness.get("design_ready", false))
	var missing_mechanics := readiness.get("missing_mechanics_ids", []) as Array
	var missing_progression := readiness.get("missing_progression_ids", []) as Array
	var reason := (
		"The 12 canonical skill identities are authoritative, but approved Combat V1 mechanics and progression remain fail-closed. Missing mechanics=%d; missing progression=%d."
		% [missing_mechanics.size(), missing_progression.size()]
	)
	if design_ready:
		reason = "Canonical skill design is frozen, but the Combat V1 skill resolver is not ready."
	blockers.append(
		_blocker("canonical_skill_mechanics_not_frozen", "skills", reason, not design_ready)
	)


func _append_monthly_economy_blocker(blockers: Array[Dictionary]) -> void:
	if not EconomyManager.has_method("get_monthly_runtime_contract"):
		blockers.append(
			_blocker(
				"monthly_economy_runtime",
				"architecture",
				"EconomyManager does not expose the canonical monthly runtime contract.",
				false
			)
		)
		return
	var contract: Dictionary = EconomyManager.get_monthly_runtime_contract()
	var ready := (
		contract.get("status") == "frozen"
		and contract.get("authority") == "monthly_economy_runtime"
		and contract.get("period") == "month"
		and contract.get("process_frequency") == "exactly_once_per_closed_month"
		and int(contract.get("fixed_monthly_cost", 0)) == 88
		and int(contract.get("slave_monthly_cost", 0)) == 5
		and int(contract.get("gladiator_monthly_cost", 0)) == 20
		and int(contract.get("beast_monthly_cost", 0)) == 10
		and contract.get("daily_economy_is_authority") == false
		and contract.get("legacy_weekly_economy_is_authority") == false
		and contract.get("invent_unfrozen_values_allowed") == false
		and contract.get("save_version_change_required") == false
	)
	if not ready:
		blockers.append(
			_blocker(
				"monthly_economy_runtime",
				"architecture",
				"Canonical monthly operating-cost runtime is incomplete or still grants authority to legacy daily/weekly economy.",
				false
			)
		)


func _append_monthly_market_blocker(blockers: Array[Dictionary]) -> void:
	if not MarketManager.has_method("get_market_rotation_policy"):
		blockers.append(
			_blocker(
				"monthly_market_cadence",
				"architecture",
				"MarketManager does not expose its canonical monthly policy.",
				false
			)
		)
		return
	var contract: Dictionary = MarketManager.get_market_rotation_policy()
	var ready := (
		contract.get("status") == "frozen"
		and contract.get("authority") == "monthly_market_policy"
		and contract.get("month_native") == true
		and contract.get("authored_unique_sync_enabled") == true
		and int(contract.get("authored_unique_sync_cadence_months", 0)) == 1
		and contract.get("procedural_auto_rotation_enabled") == false
		and contract.get("manual_equipment_refresh_enabled") == false
		and contract.get("procedural_recruit_generation_enabled") == false
		and contract.get("procedural_equipment_generation_enabled") == false
		and contract.get("legacy_three_turn_cadence_is_authoritative") == false
		and contract.get("legacy_equipment_refresh_cost_is_authoritative") == false
		and contract.get("invent_missing_balance_allowed") == false
		and contract.get("save_version_change_required") == false
	)
	if not ready:
		blockers.append(
			_blocker(
				"monthly_market_cadence",
				"architecture",
				"Canonical monthly market cadence is incomplete or still grants authority to procedural/legacy refresh paths.",
				false
			)
		)


func _append_monthly_roster_blocker(blockers: Array[Dictionary]) -> void:
	if not RosterManager.has_method("get_monthly_work_policy"):
		blockers.append(
			_blocker(
				"monthly_roster_work_recovery",
				"architecture",
				"RosterManager does not expose the canonical monthly work policy.",
				false
			)
		)
		return
	var contract: Dictionary = RosterManager.get_monthly_work_policy()
	var treatment_costs := contract.get("treatment_costs", {}) as Dictionary
	var treatment_recovery := contract.get("treatment_recovery_months", {}) as Dictionary
	var ready := (
		contract.get("status") == "frozen"
		and contract.get("authority") == "monthly_roster_work_policy"
		and contract.get("period") == "month"
		and contract.get("process_frequency") == "exactly_once_per_closed_month"
		and contract.get("migration_mode") == "one_legacy_turn_equals_one_monthly_turn"
		and contract.get("work_outputs_enabled") == true
		and contract.get("training_progress_enabled") == true
		and contract.get("fatigue_mutation_enabled") == true
		and contract.get("injury_auto_recovery_enabled") == true
		and contract.get("injury_treatment_enabled") == true
		and contract.get("fatigue_combat_availability_enabled") == true
		and int(contract.get("fatigue_combat_limit", 0)) == 90
		and int(contract.get("slave_promotion_training_threshold", 0)) == 100
		and int(treatment_costs.get("basic", 0)) == 45
		and int(treatment_costs.get("intensive", 0)) == 95
		and int(treatment_costs.get("specialist", 0)) == 180
		and int(treatment_recovery.get("basic", 0)) == 1
		and int(treatment_recovery.get("intensive", 0)) == 2
		and int(treatment_recovery.get("specialist", 0)) == 3
		and contract.get("legacy_daily_formula_allowed") == false
		and contract.get("legacy_weekly_formula_allowed") == false
		and contract.get("legacy_values_scaled_for_months") == false
		and contract.get("invent_monthly_values_allowed") == false
		and contract.get("save_version_change_required") == false
	)
	if not ready:
		blockers.append(
			_blocker(
				"monthly_roster_work_recovery",
				"architecture",
				"Monthly roster work, training, fatigue, recovery or treatment runtime is incomplete or diverges from the authored one-turn migration contract.",
				false
			)
		)


func _append_equipment_blocker(blockers: Array[Dictionary]) -> void:
	if (
		not EquipmentManager.has_method("get_runtime_policy")
		or not EquipmentManager.has_method("get_combat_v1_equipped_stats")
	):
		blockers.append(
			_blocker(
				"equipment_catalog_and_forge_balance",
				"equipment",
				"EquipmentManager does not expose the canonical demo equipment runtime and Combat V1 snapshot APIs.",
				false
			)
		)
		return
	var contract: Dictionary = EquipmentManager.get_runtime_policy()
	var multipliers := contract.get("quality_multipliers", {}) as Dictionary
	var ready := (
		contract.get("status") == "frozen"
		and contract.get("authority") == "equipment_runtime_policy"
		and contract.get("catalog_scope") == "demo_v1_authored_catalog"
		and int(contract.get("demo_catalog_size", 0)) == 15
		and DataRepository.weapons.size() == 15
		and contract.get("structural_inventory_enabled") == true
		and contract.get("equip_unequip_enabled") == true
		and contract.get("save_v14_equipment_enabled") == true
		and contract.get("forge_crafting_enabled") == true
		and contract.get("forge_recipe_costs_ready") == true
		and contract.get("forge_quality_roll_enabled") == true
		and is_equal_approx(float(multipliers.get("Común", 0.0)), 1.0)
		and is_equal_approx(float(multipliers.get("Superior", 0.0)), 1.15)
		and is_equal_approx(float(multipliers.get("Magistral", 0.0)), 1.35)
		and contract.get("item_power_defense_combat_v1_enabled") == true
		and contract.get("combat_v1_stat_source")
		== "canonical_equipped_items_after_quality_multiplier"
		and contract.get("legacy_ability_tag_gating_authoritative") == false
		and contract.get("catalog_breadth_ready") == true
		and contract.get("full_game_catalog_frozen") == false
		and contract.get("invent_missing_items_allowed") == false
		and contract.get("invent_missing_balance_allowed") == false
		and contract.get("save_version_change_required") == false
	)
	if not ready:
		blockers.append(
			_blocker(
				"equipment_catalog_and_forge_balance",
				"equipment",
				"The authored 15-item demo catalog, forge recipes, quality multipliers or Combat V1 power/defense authority are incomplete.",
				false
			)
		)


func _append_monthly_event_blocker(blockers: Array[Dictionary]) -> void:
	if not EventManager.has_method("get_monthly_runtime_contract"):
		blockers.append(
			_blocker(
				"monthly_event_cadence",
				"events",
				"EventManager does not expose the canonical monthly event runtime contract.",
				false
			)
		)
		return
	var contract: Dictionary = EventManager.get_monthly_runtime_contract()
	var event_rules := contract.get("event_rules", {}) as Dictionary
	var timed_effect_months := contract.get("timed_effect_months", {}) as Dictionary
	var grain_rule := event_rules.get("grain_shortage", {}) as Dictionary
	var patron_rule := event_rules.get("patron_invitation", {}) as Dictionary
	var ready := (
		contract.get("status") == "frozen"
		and contract.get("authority") == "monthly_event_runtime_policy"
		and contract.get("scheduler_authority") == "event_manager_demo.process_month"
		and contract.get("period") == "month"
		and contract.get("process_frequency") == "exactly_once_per_month"
		and contract.get("migration_mode") == "one_legacy_turn_equals_one_monthly_turn"
		and int(contract.get("authored_event_count", 0)) == 8
		and contract.get("authored_random_event_generation_enabled") == true
		and contract.get("monthly_cooldown_tick_enabled") == true
		and contract.get("monthly_timed_effect_tick_enabled") == true
		and int(contract.get("chain_followup_delay_months", 0)) == 1
		and int(grain_rule.get("weight", 0)) == 18
		and int(grain_rule.get("cooldown_months", 0)) == 3
		and int(patron_rule.get("cooldown_months", 0)) == 5
		and int(timed_effect_months.get("rationing", 0)) == 1
		and int(timed_effect_months.get("official_hostility", 0)) == 2
		and contract.get("legacy_random_event_generation_allowed") == false
		and contract.get("legacy_cooldown_tick_allowed") == false
		and contract.get("legacy_timed_effect_tick_allowed") == false
		and contract.get("weekly_duration_to_months_conversion_allowed") == false
		and contract.get("proportional_legacy_scaling_allowed") == false
		and contract.get("authored_turn_value_relabel_allowed") == true
		and contract.get("unknown_legacy_timed_effects_fail_closed") == true
		and contract.get("invent_monthly_cadence_allowed") == false
		and contract.get("save_version_change_required") == false
	)
	if not ready:
		blockers.append(
			_blocker(
				"monthly_event_cadence",
				"events",
				"Authored event weights, monthly cooldowns, timed effects or exactly-once monthly scheduling are incomplete.",
				false
			)
		)


func _append_authority_boundary_blockers(blockers: Array[Dictionary]) -> void:
	for code in PENDING_AUTHORITY_BOUNDARIES.keys():
		blockers.append(
			_blocker(str(code), "architecture", str(PENDING_AUTHORITY_BOUNDARIES[code]), false)
		)


func _blocker(code: String, category: String, reason: String, design_blocked: bool) -> Dictionary:
	return {
		"code": code,
		"category": category,
		"reason": reason,
		"design_blocked": design_blocked,
		"invent_values_allowed": false,
	}
