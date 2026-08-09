extends RefCounted

const GT1StandingsTiebreakPolicyScript = preload(
	"res://scripts/combat/gt1_standings_tiebreak_policy.gd"
)
const GT1PodiumTiebreakContractScript = preload(
	"res://scripts/combat/gt1_podium_tiebreak_contract.gd"
)

const MAX_GT1_POINTS := 27
const MAX_GT1_WINS := 9
const REQUIRED_RIVAL_RESULTS := 7

var _tiebreak_policy = GT1StandingsTiebreakPolicyScript.new()
var _podium_tiebreak_contract = GT1PodiumTiebreakContractScript.new()


func register_result(rival_id: String, points: int, wins: int) -> Dictionary:
	var identity := DataRepository.get_rival_ludus(rival_id)
	if identity.is_empty():
		return _rejected("unknown_rival_ludus", ["Unknown canonical rival Ludus id: %s" % rival_id])
	if points < 0 or points > MAX_GT1_POINTS:
		return _rejected(
			"invalid_rival_points",
			["GT I rival points must be between 0 and %d" % MAX_GT1_POINTS],
		)
	if wins < 0 or wins > MAX_GT1_WINS:
		return _rejected(
			"invalid_rival_wins",
			["GT I rival wins must be between 0 and %d" % MAX_GT1_WINS],
		)
	if points != wins * 3:
		return _rejected(
			"inconsistent_rival_score",
			["GT I rival points must equal wins × 3"],
		)

	var registered := (
		TournamentManager
		. register_gt1_rival_result(
			rival_id,
			str(identity.get("name", rival_id)),
			points,
			wins,
		)
	)
	if not registered:
		return _rejected(
			"tournament_manager_rejected_rival_result",
			["TournamentManager rejected the explicit GT I rival result"],
		)
	return {
		"status": "registered",
		"reason": "",
		"errors": [],
		"rival_id": rival_id,
		"rival_name": str(identity.get("name", rival_id)),
		"points": points,
		"wins": wins,
		"identity_source": "DataRepository.rival_ludi",
		"score_source": "explicit_external_result",
		"generated_score": false,
		"standings_resolution": evaluate_current_standings(),
	}


func evaluate_current_standings(non_podium_tiebreak_data: Dictionary = {}) -> Dictionary:
	var summary := TournamentManager.get_gt1_summary()
	if not bool(summary.get("player_series_complete", false)):
		return _pending("player_series_incomplete", summary)
	if int(summary.get("rival_results_registered", 0)) != REQUIRED_RIVAL_RESULTS:
		return _pending("rival_results_incomplete", summary)

	var standings_value: Variant = summary.get("standings", null)
	if not standings_value is Array:
		return {
			"status": "rejected",
			"reason": "invalid_tournament_standings",
			"errors": ["TournamentManager did not expose GT I standings as an Array"],
			"requires_combat_tiebreak": false,
			"requires_non_podium_data": false,
			"resolution_source": "gt1_standings_tiebreak_policy",
		}
	var standings := standings_value as Array
	if standings.size() != REQUIRED_RIVAL_RESULTS + 1:
		return {
			"status": "rejected",
			"reason": "incomplete_tournament_standings",
			"errors": ["GT I standings require player plus seven canonical rival Ludi"],
			"requires_combat_tiebreak": false,
			"requires_non_podium_data": false,
			"resolution_source": "gt1_standings_tiebreak_policy",
		}

	var result: Dictionary = (
		_tiebreak_policy
		. evaluate(
			standings,
			non_podium_tiebreak_data,
			"player",
		)
	)
	result["resolution_source_contract"] = "gt1_standings_tiebreak_policy"
	result["applied_to_tournament_manager"] = false
	if (
		result.get("status") == "resolved"
		and result.get("resolution_source") == "head_to_head_then_prior_season_position"
	):
		result["applied_to_tournament_manager"] = (TournamentManager.apply_gt1_standings_resolution(
			result
		))
	return result


func build_podium_tiebreak_request() -> Dictionary:
	var standings_resolution := evaluate_current_standings()
	var summary := TournamentManager.get_gt1_summary()
	return _podium_tiebreak_contract.build_request(
		standings_resolution,
		summary.get("standings", []) as Array,
	)


func resolve_podium_tiebreak(
	combat_result: Dictionary, team_to_ludus: Dictionary
) -> Dictionary:
	var request := build_podium_tiebreak_request()
	if request.get("status") != "ready":
		return request
	var resolution: Dictionary = _podium_tiebreak_contract.resolve_combat_result(
		request,
		combat_result,
		team_to_ludus,
	)
	if resolution.get("status") == "resolved":
		resolution["applied_to_tournament_manager"] = (
			TournamentManager.apply_gt1_standings_resolution(resolution)
		)
	return resolution


func get_contract() -> Dictionary:
	return {
		"status": "frozen",
		"identity_source": "DataRepository.rival_ludi",
		"score_source": "explicit_external_result",
		"legacy_rival_manager_is_score_authority": false,
		"generated_score_allowed": false,
		"points_per_win": 3,
		"max_points": MAX_GT1_POINTS,
		"max_wins": MAX_GT1_WINS,
		"required_rival_results": REQUIRED_RIVAL_RESULTS,
		"standings_resolution_policy": "gt1_standings_tiebreak_policy",
		"podium_tie_resolution": "tournament_characteristic_combat",
		"podium_tiebreak_contract": "gt1_podium_tiebreak_contract",
		"exact_championship_tiebreak": "two_ludi_tied_first_at_27_points",
		"exact_championship_format": "1v1",
		"exact_championship_points_awarded": 0,
		"non_podium_tie_resolution": ["head_to_head", "prior_season_position"],
		"resolved_tiebreak_authority": "TournamentManager",
		"resolved_tiebreak_uses_existing_save_v14_fields": true,
		"alphabetical_fallback_allowed": false,
		"random_fallback_allowed": false,
	}


func _pending(reason: String, summary: Dictionary) -> Dictionary:
	return {
		"status": "pending_results",
		"reason": reason,
		"errors": [],
		"player_series_complete": bool(summary.get("player_series_complete", false)),
		"rival_results_registered": int(summary.get("rival_results_registered", 0)),
		"required_rival_results": REQUIRED_RIVAL_RESULTS,
		"requires_combat_tiebreak": false,
		"requires_non_podium_data": false,
		"resolution_source": "gt1_standings_tiebreak_policy",
	}


func _rejected(reason: String, errors: Array[String]) -> Dictionary:
	return {
		"status": "rejected",
		"reason": reason,
		"errors": errors.duplicate(),
		"rival_id": "",
		"rival_name": "",
		"points": 0,
		"wins": 0,
		"identity_source": "DataRepository.rival_ludi",
		"score_source": "explicit_external_result",
		"generated_score": false,
		"standings_resolution": {},
	}
