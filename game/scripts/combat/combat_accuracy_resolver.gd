extends RefCounted

const ACTION_ACCURACY_MODIFIERS := {
	"light": 1.0,
	"heavy": 0.0,
}
const ATTACKER_STAT := "TEC"
const DEFENDER_STAT := "AGI"


func resolve_hit(attacker: Dictionary, defender: Dictionary, action_id: String) -> Dictionary:
	if not ACTION_ACCURACY_MODIFIERS.has(action_id):
		return _invalid("unsupported_accuracy_action")

	var attacker_stats := attacker.get("stats", {}) as Dictionary
	var defender_stats := defender.get("stats", {}) as Dictionary
	var errors: Array[String] = []
	_validate_stat(attacker_stats, ATTACKER_STAT, "attacker", errors)
	_validate_stat(defender_stats, DEFENDER_STAT, "defender", errors)
	if not errors.is_empty():
		return {"status": "invalid", "errors": errors}

	var action_modifier: float = float(ACTION_ACCURACY_MODIFIERS[action_id])
	var attack_score: float = float(attacker_stats.get(ATTACKER_STAT, 0.0)) + action_modifier
	var evasion_score: float = float(defender_stats.get(DEFENDER_STAT, 0.0))
	var hit: bool = attack_score >= evasion_score
	return {
		"status": "resolved",
		"errors": [],
		"action_id": action_id,
		"hit": hit,
		"critical": false,
		"attack_score": attack_score,
		"evasion_score": evasion_score,
		"action_accuracy_modifier": action_modifier,
	}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"owner": "combat_simulator",
		"deterministic": true,
		"rng_allowed": false,
		"critical_hits_enabled": false,
		"attacker_stat": ATTACKER_STAT,
		"defender_stat": DEFENDER_STAT,
		"action_accuracy_modifiers": ACTION_ACCURACY_MODIFIERS.duplicate(true),
		"hit_rule": "attack_score_gte_evasion_score",
	}


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
