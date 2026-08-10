extends Node

signal combat_finished(result: Dictionary)
signal combat_failed(reason: String)
signal combat_turn(action: Dictionary)

const STATUS := "legacy_combat_manager_quarantined"
const REASON := (
	"CombatManager legacy está en cuarentena. Los combates jugables deben resolverse "
	+ "exclusivamente mediante Combat V1 / CombatSimulator."
)

# Save-v14 compatibility state only. These values are intentionally not combat authority.
var last_result: Dictionary = {}
var last_combat_day: int = -1
var next_battle_config: Dictionary = {}


func get_quarantine_contract() -> Dictionary:
	return {
		"status": STATUS,
		"legacy_runtime_authority": false,
		"combat_v1_authority": "CombatSimulator",
		"legacy_scheduling_enabled": false,
		"legacy_ability_mechanics_enabled": false,
		"legacy_beast_combat_enabled": false,
		"legacy_rewards_enabled": false,
		"legacy_injuries_enabled": false,
		"legacy_fatigue_mutation_enabled": false,
		"save_v14_compatibility_state_preserved": true,
	}


func is_quarantined() -> bool:
	return true


func get_tactic_ids() -> Array[String]:
	return []


func get_tactic_name(tactic_id: String) -> String:
	return tactic_id


func get_ability_ids() -> Array[String]:
	return []


func get_ability(_ability_id: String, _level: int = 1) -> Dictionary:
	return {}


func get_technique_ids() -> Array[String]:
	return []


func get_technique(_technique_id: String) -> Dictionary:
	return {}


func configure_next_battle(config: Dictionary) -> void:
	# Keep incoming configuration only as inert v14 compatibility evidence.
	next_battle_config = config.duplicate(true)


func get_event_type_for_week(_week: int) -> String:
	return "combat_v1_only"


func get_event_name_for_week(_week: int) -> String:
	return ""


func get_event_details_for_week(_week: int) -> Dictionary:
	return get_current_event_details()


func get_current_event_type() -> String:
	return "combat_v1_only"


func get_current_event_name() -> String:
	return "Combat V1"


func get_current_event_details() -> Dictionary:
	return {
		"type": "combat_v1_only",
		"name": "Combat V1",
		"rules": REASON,
		"risk": "Pendiente de flujo jugable Combat V1",
		"reward": "Sin recompensa legacy",
		"team_size": 0,
		"opponent_class": "none",
		"legacy_quarantined": true,
	}


func get_next_event_summary() -> String:
	return REASON


func get_current_opponent_preview(_fighter_id: String = "") -> Dictionary:
	return {
		"known": false,
		"kind": "combat_v1_pending_ui",
		"title": "Combat V1",
		"description": REASON,
	}


func simulate_duel(_gladiator_id: String, _tactic: String = "balanced") -> Dictionary:
	combat_failed.emit(REASON)
	return {}
