extends RefCounted

const DEFENSE_ACTIONS: Array[String] = ["block", "parry", "dodge", "reposition"]
const BLOCK_RES_COEFFICIENT := 0.25
const DODGE_EVASION_BONUS := 2.0
const REPOSITION_EVASION_BONUS := 1.0


func resolve_against_attack(
	attacker: Dictionary,
	defender: Dictionary,
	offense_action_id: String,
	defense_action_id: String,
	accuracy_result: Dictionary,
	damage_result: Dictionary
) -> Dictionary:
	if not DEFENSE_ACTIONS.has(defense_action_id):
		return _invalid("unsupported_defense_action")
	if accuracy_result.get("status") != "resolved":
		return _invalid("accuracy_result_not_resolved")
	if damage_result.get("status") != "resolved":
		return _invalid("damage_result_not_resolved")
	if str(accuracy_result.get("action_id", "")) != offense_action_id:
		return _invalid("accuracy_action_mismatch")
	if str(damage_result.get("action_id", "")) != offense_action_id:
		return _invalid("damage_action_mismatch")

	var attacker_stats := attacker.get("stats", {}) as Dictionary
	var defender_stats := defender.get("stats", {}) as Dictionary
	var errors: Array[String] = []
	_validate_stat(attacker_stats, "TEC", "attacker", errors)
	_validate_stat(defender_stats, "AGI", "defender", errors)
	_validate_stat(defender_stats, "TEC", "defender", errors)
	_validate_stat(defender_stats, "RES", "defender", errors)
	if not errors.is_empty():
		return {"status": "invalid", "errors": errors}

	var base_hit: bool = bool(accuracy_result.get("hit", false))
	var base_damage: int = int(damage_result.get("damage", 0))
	if not base_hit:
		base_damage = 0

	var result := {
		"status": "resolved",
		"errors": [],
		"offense_action_id": offense_action_id,
		"defense_action_id": defense_action_id,
		"hit": base_hit,
		"damage": base_damage,
		"blocked_amount": 0,
		"parried": false,
		"dodged": false,
		"reposition_evaded": false,
		"clear_vulnerable": defense_action_id == "reposition",
		"attack_score": float(accuracy_result.get("attack_score", 0.0)),
		"effective_evasion_score": float(accuracy_result.get("evasion_score", 0.0)),
	}

	match defense_action_id:
		"block":
			_apply_block(result, defender_stats)
		"parry":
			_apply_parry(result, defender_stats)
		"dodge":
			_apply_evasion(result, DODGE_EVASION_BONUS, "dodged")
		"reposition":
			_apply_evasion(result, REPOSITION_EVASION_BONUS, "reposition_evaded")

	return result


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"owner": "combat_simulator",
		"deterministic": true,
		"rng_allowed": false,
		"scope": "current_exchange",
		"applies_to_each_incoming_attack": true,
		"block":
		{
			"stat": "RES",
			"reduction_coefficient": BLOCK_RES_COEFFICIENT,
			"reduction_rounding": "ceil",
			"minimum_post_block_damage": 0,
		},
		"parry":
		{
			"stat": "TEC",
			"success_rule": "defender_tec_gte_attack_score",
			"success_damage": 0,
		},
		"dodge":
		{
			"stat": "AGI",
			"evasion_bonus": DODGE_EVASION_BONUS,
			"hit_rule": "attack_score_gte_effective_evasion_score",
		},
		"reposition":
		{
			"stat": "AGI",
			"evasion_bonus": REPOSITION_EVASION_BONUS,
			"hit_rule": "attack_score_gte_effective_evasion_score",
			"clear_vulnerable": true,
			"distance_model_required": false,
		},
	}


func _apply_block(result: Dictionary, defender_stats: Dictionary) -> void:
	if not bool(result.get("hit", false)):
		return
	var reduction: int = int(ceil(float(defender_stats.get("RES", 0.0)) * BLOCK_RES_COEFFICIENT))
	var base_damage: int = int(result.get("damage", 0))
	var final_damage: int = maxi(0, base_damage - reduction)
	result["blocked_amount"] = base_damage - final_damage
	result["damage"] = final_damage


func _apply_parry(result: Dictionary, defender_stats: Dictionary) -> void:
	if not bool(result.get("hit", false)):
		return
	var parry_score: float = float(defender_stats.get("TEC", 0.0))
	if parry_score >= float(result.get("attack_score", 0.0)):
		result["hit"] = false
		result["damage"] = 0
		result["parried"] = true


func _apply_evasion(result: Dictionary, bonus: float, outcome_key: String) -> void:
	var effective_evasion: float = float(result.get("effective_evasion_score", 0.0)) + bonus
	result["effective_evasion_score"] = effective_evasion
	if (
		bool(result.get("hit", false))
		and float(result.get("attack_score", 0.0)) < effective_evasion
	):
		result["hit"] = false
		result["damage"] = 0
		result[outcome_key] = true


func _validate_stat(
	stats: Dictionary, stat_id: String, role: String, errors: Array[String]
) -> void:
	if not stats.has(stat_id) or not _is_numeric(stats[stat_id]):
		errors.append("%s stat %s must be numeric" % [role, stat_id])
		return
	if float(stats[stat_id]) < 0.0:
		errors.append("%s stat %s cannot be negative" % [role, stat_id])


func _invalid(error: String) -> Dictionary:
	return {"status": "invalid", "errors": [error]}


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float
