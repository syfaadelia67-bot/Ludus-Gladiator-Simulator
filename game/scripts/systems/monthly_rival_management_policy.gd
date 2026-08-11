extends RefCounted

const STATUS := "frozen"
const PERIOD := "month"
const PROCESS_FREQUENCY := "exactly_once_per_month"
const MIGRATION_MODE := "one_legacy_turn_equals_one_monthly_turn"

const OPERATION_RULES := {
	"scout": {"name": "Explorar ludus", "intel_cost": 0, "denarii_cost": 20, "risk": 12},
	"steal_plans":
	{"name": "Robar planes de combate", "intel_cost": 12, "denarii_cost": 35, "risk": 28},
	"poison_supplies":
	{"name": "Envenenar suministros", "intel_cost": 20, "denarii_cost": 55, "risk": 42},
	"bribe_guard": {"name": "Sobornar guardia", "intel_cost": 8, "denarii_cost": 90, "risk": 22},
	"spread_rumors": {"name": "Difundir rumores", "intel_cost": 15, "denarii_cost": 50, "risk": 34},
}

# These are the explicit fallback values already authored by the legacy rival kernel.
# They are reused as neutral management baselines for the seven canonical Ludi.
const MANAGEMENT_BASELINE := {
	"wealth": 50,
	"security": 50,
	"prestige": 50,
	"relation": 0,
	"intel": 0,
	"suspicion": 0,
	"gladiator_power": 50,
	"status": "Activo",
}

const LEGACY_RIVAL_ID_ALIASES := {
	"house_cassian": "cassianus",
	"house_varro": "varro",
}

const OPERATION_FORMULA := {
	"intelligence_weight": 6,
	"agility_weight": 3,
	"loyalty_divisor": 5,
	"mentor_bonus": 6,
	"freedom_seeker_penalty": 5,
	"success_base": 45,
	"skill_divisor": 3,
	"defense_suspicion_divisor": 2,
	"defense_divisor": 2,
	"success_min": 12,
	"success_max": 92,
	"detection_defense_divisor": 4,
	"detection_agility_weight": 2,
	"detection_min": 5,
	"detection_max": 85,
	"success_loyalty_gain": 2,
	"failure_fatigue_gain": 8,
	"detected_heat_gain": 12,
	"detected_relation_loss": 18,
	"detected_suspicion_gain": 22,
	"detected_reputation_loss": 2,
	"detected_agent_morale_loss": 5,
	"undetected_suspicion_decay": 3,
}

const OPERATION_EFFECTS := {
	"scout": {"intel_gain_min": 8, "intel_gain_max": 16, "player_intel_gain": 3},
	"steal_plans":
	{"management_power_loss_min": 4, "management_power_loss_max": 9, "player_intel_gain": 8},
	"poison_supplies":
	{"management_power_loss_min": 8, "management_power_loss_max": 15, "prestige_loss": 3},
	"bribe_guard": {"security_loss_min": 7, "security_loss_max": 13, "rival_intel_gain": 12},
	"spread_rumors": {"prestige_loss_min": 6, "prestige_loss_max": 12, "player_reputation_gain": 1},
}

const RETALIATION_RULES := {
	"hostility_heat_decay": 1,
	"suspicion_decay": 1,
	"relation_threshold": -45,
	"base_chance": 0.10,
	"heat_divisor": 300.0,
	"security_roll_min": 1,
	"security_roll_max": 30,
	"blocked_relation_loss": 2,
	"denarii_loss_min": 35,
	"denarii_loss_max": 110,
	"food_loss_min": 4,
	"food_loss_max": 12,
}


func get_operation_ids() -> Array[String]:
	var result: Array[String] = []
	for operation_id in OPERATION_RULES.keys():
		result.append(str(operation_id))
	return result


func get_operation(operation_id: String) -> Dictionary:
	var data := OPERATION_RULES.get(operation_id, {}) as Dictionary
	return data.duplicate(true)


func get_operation_block_reason(operation_id: String) -> String:
	if not OPERATION_RULES.has(operation_id):
		return "La operación rival seleccionada no pertenece al catálogo canónico conocido."
	return ""


func build_management_profile(identity: Dictionary) -> Dictionary:
	var profile := MANAGEMENT_BASELINE.duplicate(true)
	profile["id"] = str(identity.get("id", ""))
	profile["name"] = str(identity.get("name", profile["id"]))
	profile["last_management_month"] = 0
	profile["management_baseline_source"] = "legacy_explicit_fallbacks"
	profile["combat_v1_authority"] = false
	return profile


func get_contract() -> Dictionary:
	return {
		"status": STATUS,
		"authority": "monthly_rival_management_policy",
		"period": PERIOD,
		"process_frequency": PROCESS_FREQUENCY,
		"migration_mode": MIGRATION_MODE,
		"canonical_rival_identity_source": "DataRepository.rival_ludi",
		"canonical_rival_count": 7,
		"management_baseline_source": "legacy_explicit_fallbacks",
		"management_baseline": MANAGEMENT_BASELINE.duplicate(true),
		"legacy_rival_id_aliases": LEGACY_RIVAL_ID_ALIASES.duplicate(true),
		"operation_count": OPERATION_RULES.size(),
		"operation_rules": OPERATION_RULES.duplicate(true),
		"operation_formula": OPERATION_FORMULA.duplicate(true),
		"operation_effects": OPERATION_EFFECTS.duplicate(true),
		"retaliation_rules": RETALIATION_RULES.duplicate(true),
		"player_initiated_operations_enabled": true,
		"operation_auto_tick_enabled": false,
		"monthly_retaliation_tick_enabled": true,
		"legacy_daily_scheduler_is_authority": false,
		"legacy_operation_execution_allowed": false,
		"legacy_retaliation_rng_allowed": false,
		"monthly_retaliation_rng_enabled": true,
		"management_gladiator_power_mutation_enabled": true,
		"gladiator_power_is_combat_v1_authority": false,
		"legacy_gladiator_power_mutation_allowed": false,
		"gt1_combat_snapshot_mutation_allowed": false,
		"gt1_standings_mutation_allowed": false,
		"invent_monthly_costs_allowed": false,
		"invent_monthly_risk_allowed": false,
		"invent_monthly_cadence_allowed": false,
		"proportional_legacy_scaling_allowed": false,
		"save_version_change_required": false,
	}
