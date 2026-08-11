extends Node

const REQUIRED_DICTIONARY_SECTIONS: Array[String] = [
	"game_state",
	"owner",
	"roster",
	"estate",
	"equipment",
	"market",
	"rivals",
	"events",
	"economy",
	"tournaments",
	"campaign",
	"personality",
	"relationships",
	"unique_gladiators",
	"owned_beasts",
	"combat_v1_runtime",
]


func run() -> void:
	var payload := SaveManager._build_payload()
	assert(int(payload.get("version", 0)) == 14)
	for section in REQUIRED_DICTIONARY_SECTIONS:
		assert(payload.has(section), "Save v14 missing canonical monthly section: %s" % section)
		assert(
			payload.get(section) is Dictionary, "Save section must be a Dictionary: %s" % section
		)

	var game_state := payload.get("game_state", {}) as Dictionary
	var month := int(game_state.get("month", 0))
	assert(month >= 1)
	assert(int(game_state.get("week", 0)) == month)
	assert(int(game_state.get("day", 0)) == month)

	var roster := payload.get("roster", {}) as Dictionary
	assert(roster.has("last_processed_month"))
	assert(roster.has("last_monthly_result"))
	assert(roster.has("monthly_policy_status"))

	var market := payload.get("market", {}) as Dictionary
	assert(market.has("last_market_rotation_month"))
	assert(
		(
			int(market.get("last_auto_refresh_month", 0))
			== int(market.get("last_market_rotation_month", -1))
		)
	)
	assert(
		(
			int(market.get("last_auto_refresh_week", 0))
			== int(market.get("last_market_rotation_month", -1))
		)
	)

	var equipment := payload.get("equipment", {}) as Dictionary
	assert(bool(equipment.get("canonical_slots_persisted", false)))
	assert(equipment.has("runtime_policy_status"))

	var tournaments := payload.get("tournaments", {}) as Dictionary
	for field in [
		"gt1_player_points",
		"gt1_player_wins",
		"gt1_player_bouts",
		"gt1_encounter_progress",
		"gt1_rival_scores",
		"gt1_standings",
		"gt1_placement",
		"gt1_medal",
		"gt1_standings_resolved",
		"gt1_tiebreak_required",
	]:
		assert(tournaments.has(field), "Save v14 missing GT I field: %s" % field)

	var owner := payload.get("owner", {}) as Dictionary
	var profile := owner.get("profile", {}) as Dictionary
	assert(profile.has("tutorial_progress"))
	assert(profile.has("tutorial_completed"))

	var runtime := payload.get("combat_v1_runtime", {}) as Dictionary
	assert(int(runtime.get("store_version", 0)) == 1)
	assert(runtime.has("gt1_session"))
	assert(runtime.has("tiebreak_session"))

	print("Canonical monthly runtime persistence audit: OK")
