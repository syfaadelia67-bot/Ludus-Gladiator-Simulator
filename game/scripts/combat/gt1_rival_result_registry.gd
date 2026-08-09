extends RefCounted

const MAX_GT1_POINTS := 27
const MAX_GT1_WINS := 9


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
	}


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
	}
