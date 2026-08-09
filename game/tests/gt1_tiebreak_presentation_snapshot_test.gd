extends Node

const GT1TiebreakPresentationSnapshotScript = preload(
	"res://scripts/combat/gt1_tiebreak_presentation_snapshot.gd"
)


func _ready() -> void:
	var snapshot = GT1TiebreakPresentationSnapshotScript.new()
	_test_exact_championship_tie_surfaces_external_rival_requirement(snapshot)
	_test_non_podium_tie_surfaces_required_data(snapshot)
	_test_unsupported_podium_tie_stays_pending(snapshot)
	_test_resolved_summary_needs_no_tiebreak(snapshot)
	_test_contract(snapshot)
	print("GT I tiebreak presentation snapshot: OK")
	get_tree().quit(0)


func _test_exact_championship_tie_surfaces_external_rival_requirement(snapshot) -> void:
	var result: Dictionary = snapshot.build(
		_summary(true, false),
		{
			"status": "podium_combat_required",
			"reason": "podium_tie",
			"tied_rival_ids": ["cassianus"],
		},
		{
			"status": "ready",
			"format": "1v1",
			"player_ludus_id": "player",
			"rival_ludus_id": "cassianus",
			"player_selection": "one_available_gladiator",
			"rival_selection": "one_available_gladiator",
			"points_awarded": 0,
			"combat_result_authority": "CombatSimulator",
			"standings_authority": "TournamentManager",
			"double_ko_resolution": "rematch_required",
		},
	)
	assert(result.get("status") == "championship_tiebreak_ready")
	assert(result.get("format") == "1v1")
	assert(result.get("rival_ludus_id") == "cassianus")
	assert(result.get("rival_ludus_name") == "Ludus Cassianus")
	assert(result.get("requires_player_gladiator_selection") == true)
	assert(result.get("requires_external_rival_snapshot") == true)
	assert(result.get("rival_snapshot_source") == "explicit_external_combat_v1_snapshot")
	assert(int(result.get("points_awarded", -1)) == 0)
	assert(result.get("presentation_may_resolve_standings") == false)


func _test_non_podium_tie_surfaces_required_data(snapshot) -> void:
	var result: Dictionary = snapshot.build(
		_summary(true, false),
		{
			"status": "non_podium_data_required",
			"reason": "non_podium_tie",
			"first_tied_position": 4,
			"last_tied_position": 5,
			"tied_rival_ids": ["cassianus"],
		},
	)
	assert(result.get("status") == "non_podium_data_required")
	assert(result.get("requires_combat") == false)
	assert(result.get("required_data") == ["head_to_head", "prior_season_position"])
	assert(int(result.get("first_tied_position", 0)) == 4)
	assert(int(result.get("last_tied_position", 0)) == 5)
	assert(result.get("tied_rival_ids") == ["cassianus"])


func _test_unsupported_podium_tie_stays_pending(snapshot) -> void:
	var result: Dictionary = snapshot.build(
		_summary(true, false),
		{
			"status": "podium_combat_required",
			"reason": "podium_tie",
		},
		{
			"status": "pending_exact_rule",
			"reason": "unsupported_podium_tie_shape",
			"errors": ["Only the exact frozen championship tie is supported"],
		},
	)
	assert(result.get("status") == "pending_exact_rule")
	assert(result.get("reason") == "unsupported_podium_tie_shape")
	assert(result.get("requires_combat") == false)
	assert(result.get("requires_external_rival_snapshot") == false)
	assert(result.get("presentation_may_resolve_standings") == false)


func _test_resolved_summary_needs_no_tiebreak(snapshot) -> void:
	var result: Dictionary = snapshot.build(_summary(false, true), {})
	assert(result.get("status") == "resolved")
	assert(result.get("requires_combat") == false)
	assert(result.get("requires_external_rival_snapshot") == false)


func _test_contract(snapshot) -> void:
	var contract: Dictionary = snapshot.get_contract()
	assert(contract.get("output") == "read_only_tiebreak_ui_snapshot")
	assert(contract.get("exact_championship_tie") == "two_ludi_tied_first_at_27_points")
	assert(contract.get("championship_format") == "1v1")
	assert(contract.get("championship_points_awarded") == 0)
	assert(contract.get("rival_snapshot_source") == "explicit_external_combat_v1_snapshot")
	assert(contract.get("rival_generation_allowed") == false)
	assert(contract.get("combat_authority") == "CombatSimulator")
	assert(contract.get("standings_authority") == "TournamentManager")
	assert(contract.get("presentation_may_resolve_standings") == false)


func _summary(tiebreak_required: bool, standings_resolved: bool) -> Dictionary:
	return {
		"tiebreak_required": tiebreak_required,
		"standings_resolved": standings_resolved,
		"standings": [
			{"id": "player", "name": "Tu Ludus", "points": 27, "wins": 9},
			{"id": "cassianus", "name": "Ludus Cassianus", "points": 27, "wins": 9},
		],
	}
