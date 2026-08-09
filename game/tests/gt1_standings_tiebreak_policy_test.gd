extends Node

const GT1StandingsTiebreakPolicyScript = preload(
	"res://scripts/combat/gt1_standings_tiebreak_policy.gd"
)


func _ready() -> void:
	var policy = GT1StandingsTiebreakPolicyScript.new()

	_test_clear_standings(policy)
	_test_podium_tie_requires_combat(policy)
	_test_non_podium_tie_requires_explicit_data(policy)
	_test_non_podium_head_to_head_resolves(policy)
	_test_non_podium_prior_season_position_resolves(policy)
	_test_missing_non_podium_data_never_falls_back(policy)
	_test_contract(policy)

	print("GT I standings tiebreak policy contract: OK")
	get_tree().quit(0)


func _test_clear_standings(policy) -> void:
	var result := (
		policy
		. evaluate(
			[
				_entry("r1", 27, 9),
				_entry("player", 24, 8),
				_entry("r2", 21, 7),
				_entry("r3", 18, 6),
			]
		)
	)
	assert(result.get("status") == "resolved")
	assert(int(result.get("placement", 0)) == 2)
	assert(str(result.get("medal", "")) == "silver")
	assert(result.get("requires_combat_tiebreak") == false)


func _test_podium_tie_requires_combat(policy) -> void:
	var result := (
		policy
		. evaluate(
			[
				_entry("player", 27, 9),
				_entry("cassianus", 27, 9),
				_entry("flavianus", 21, 7),
				_entry("drusus", 18, 6),
			]
		)
	)
	assert(result.get("status") == "podium_combat_required")
	assert(result.get("requires_combat_tiebreak") == true)
	assert(result.get("requires_non_podium_data") == false)
	assert(int(result.get("placement", -1)) == 0)
	assert(str(result.get("medal", "x")).is_empty())
	assert(result.get("tied_rival_ids") == ["cassianus"])


func _test_non_podium_tie_requires_explicit_data(policy) -> void:
	var result := policy.evaluate(_non_podium_tie_fixture())
	assert(result.get("status") == "non_podium_data_required")
	assert(result.get("requires_combat_tiebreak") == false)
	assert(result.get("requires_non_podium_data") == true)
	assert(int(result.get("first_tied_position", 0)) == 4)
	assert(int(result.get("last_tied_position", 0)) == 5)
	assert(_contains_error(result, "Missing non-podium tiebreak data for cassianus"))


func _test_non_podium_head_to_head_resolves(policy) -> void:
	var player_wins := (
		policy
		. evaluate(
			_non_podium_tie_fixture(),
			{
				"cassianus": {"head_to_head_winner_id": "player"},
			}
		)
	)
	assert(player_wins.get("status") == "resolved")
	assert(int(player_wins.get("placement", 0)) == 4)
	assert(str(player_wins.get("medal", "x")).is_empty())
	assert(player_wins.get("resolution_source") == "head_to_head_then_prior_season_position")

	var rival_wins := (
		policy
		. evaluate(
			_non_podium_tie_fixture(),
			{
				"cassianus": {"head_to_head_winner_id": "cassianus"},
			}
		)
	)
	assert(rival_wins.get("status") == "resolved")
	assert(int(rival_wins.get("placement", 0)) == 5)


func _test_non_podium_prior_season_position_resolves(policy) -> void:
	var result := (
		policy
		. evaluate(
			_non_podium_tie_fixture(),
			{
				"cassianus":
				{
					"head_to_head_winner_id": "",
					"player_prior_season_position": 6,
					"rival_prior_season_position": 4,
				},
			}
		)
	)
	assert(result.get("status") == "resolved")
	assert(int(result.get("placement", 0)) == 5)
	assert(result.get("used_non_podium_tiebreak") == true)


func _test_missing_non_podium_data_never_falls_back(policy) -> void:
	var result := (
		policy
		. evaluate(
			_non_podium_tie_fixture(),
			{
				"cassianus":
				{
					"head_to_head_winner_id": "",
					"player_prior_season_position": 0,
					"rival_prior_season_position": 0,
				},
			}
		)
	)
	assert(result.get("status") == "non_podium_data_required")
	assert(int(result.get("placement", -1)) == 0)
	assert(_contains_error(result, "Incomplete non-podium tiebreak data for cassianus"))


func _test_contract(policy) -> void:
	var contract := policy.get_contract()
	assert(contract.get("podium_tie") == "tournament_characteristic_combat")
	assert(contract.get("non_podium_tie") == ["head_to_head", "prior_season_position"])
	assert(contract.get("missing_non_podium_data") == "pending")
	assert(contract.get("alphabetical_fallback_allowed") == false)
	assert(contract.get("random_fallback_allowed") == false)


func _non_podium_tie_fixture() -> Array:
	return [
		_entry("aurelius", 27, 9),
		_entry("flavianus", 24, 8),
		_entry("drusus", 21, 7),
		_entry("player", 18, 6),
		_entry("cassianus", 18, 6),
		_entry("severus", 15, 5),
		_entry("marcellus", 12, 4),
		_entry("varro", 9, 3),
	]


func _entry(entry_id: String, points: int, wins: int) -> Dictionary:
	return {
		"id": entry_id,
		"name": entry_id,
		"points": points,
		"wins": wins,
	}


func _contains_error(result: Dictionary, fragment: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).contains(fragment):
			return true
	return false
