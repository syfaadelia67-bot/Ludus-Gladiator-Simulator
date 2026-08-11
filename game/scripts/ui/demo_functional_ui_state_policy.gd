extends RefCounted

const ROUTE_IDS: Array[String] = [
	"finca",
	"barracks",
	"bestias",
	"mercado",
	"arena",
	"equipamiento",
	"personal",
	"forja",
	"gladiator_dossier",
	"campana",
	"eventos",
	"rivales",
	"economia",
	"torneos",
	"progresion",
	"personalidad",
	"relaciones",
	"transferencias",
	"historial",
]
const SUPPORTED_STATES: Array[String] = [
	"ready",
	"empty",
	"blocked",
	"error",
	"completed_read_only",
]
const ROSTER_DEPENDENT_ROUTES: Array[String] = [
	"barracks",
	"personal",
	"equipamiento",
	"gladiator_dossier",
	"relaciones",
	"personalidad",
	"transferencias",
]


func evaluate(system_id: String) -> Dictionary:
	var normalized := system_id.strip_edges().to_lower()
	if not ROUTE_IDS.has(normalized):
		return _state(
			"error",
			"UI_STATE_LABEL_ERROR",
			"UI_STATE_ROUTE_ERROR",
			{"route": normalized if not normalized.is_empty() else "?"},
		)
	if CampaignManager.campaign_over:
		return _state(
			"completed_read_only",
			"UI_STATE_LABEL_READ_ONLY",
			"UI_STATE_COMPLETED_READ_ONLY",
		)
	if ROSTER_DEPENDENT_ROUTES.has(normalized) and RosterManager.get_people().is_empty():
		return _state("empty", "UI_STATE_LABEL_EMPTY", "UI_STATE_EMPTY_ROSTER")
	var contextual_state := _evaluate_contextual_state(normalized)
	if not contextual_state.is_empty():
		return contextual_state
	return _state("ready", "UI_STATE_LABEL_READY", "")


func _evaluate_contextual_state(system_id: String) -> Dictionary:
	match system_id:
		"mercado":
			return _evaluate_market_state()
		"bestias":
			return _evaluate_beast_state()
		"arena":
			return _evaluate_arena_state()
		"progresion":
			return _state(
				"blocked",
				"UI_STATE_LABEL_BLOCKED",
				"UI_STATE_BLOCKED_PROGRESSION",
			)
		"historial":
			return _state(
				"blocked",
				"UI_STATE_LABEL_BLOCKED",
				"UI_STATE_BLOCKED_COMBAT_HISTORY",
			)
		_:
			return {}


func _evaluate_market_state() -> Dictionary:
	if MarketManager.get_offers().is_empty() and MarketManager.get_equipment_offers().is_empty():
		return _state("empty", "UI_STATE_LABEL_EMPTY", "UI_STATE_EMPTY_MARKET")
	return {}


func _evaluate_beast_state() -> Dictionary:
	if EstateManager.is_locked("beast_area"):
		return _state("blocked", "UI_STATE_LABEL_BLOCKED", "UI_STATE_BLOCKED_BEAST_AREA")
	if OwnedBeastRegistry.get_owned_count() == 0:
		return _state("empty", "UI_STATE_LABEL_EMPTY", "UI_STATE_EMPTY_BEASTS")
	return {}


func _evaluate_arena_state() -> Dictionary:
	var month := GameState.get_month()
	if TournamentManager.get_gt1_encounter(month).is_empty():
		return _state(
			"blocked",
			"UI_STATE_LABEL_BLOCKED",
			"UI_STATE_BLOCKED_ARENA_NON_GT",
			{"month": month},
		)
	if (
		CombatV1SessionStore.get_gt1_session(month).is_empty()
		and DataRepository.get_rival_combat_v1_snapshots().is_empty()
	):
		return _state(
			"blocked",
			"UI_STATE_LABEL_BLOCKED",
			"UI_STATE_BLOCKED_ARENA_RIVAL_DATA",
		)
	return {}


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"scope": "demo_placeholder_functional_ui",
		"route_ids": ROUTE_IDS.duplicate(),
		"supported_states": SUPPORTED_STATES.duplicate(),
		"presentation_only": true,
		"gameplay_authority": false,
		"completed_campaign_state": "completed_read_only",
		"unknown_route_state": "error",
		"final_art_required": false,
		"save_version_change_required": false,
	}


func _state(
	state_id: String,
	label_key: String,
	message_key: String,
	values: Dictionary = {},
) -> Dictionary:
	return {
		"state": state_id,
		"label_key": label_key,
		"message_key": message_key,
		"values": values.duplicate(true),
		"blocks_navigation": false,
		"presentation_only": true,
	}
