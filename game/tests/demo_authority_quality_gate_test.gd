extends Node

const CANONICAL_COMBAT_FILES: Array[String] = [
	"res://scripts/combat/combat_simulator.gd",
	"res://scripts/combat/combat_1v1_loop.gd",
	"res://scripts/combat/combat_1v2_loop.gd",
	"res://scripts/combat/combat_2v2_loop.gd",
	"res://scripts/combat/gt1_combat_runtime.gd",
	"res://scripts/combat/gt1_championship_tiebreak_runtime.gd",
	"res://scripts/combat/gt1_combat_intent_bridge.gd",
	"res://scripts/combat/gt1_month_13_host.gd",
	"res://scripts/combat/gt1_month_16_host.gd",
	"res://scripts/combat/gt1_month_20_host.gd",
	"res://scripts/ui/combat_v1_arena_runtime.gd",
	"res://scripts/systems/campaign_manager_demo.gd",
]
const CANONICAL_MONTHLY_FILES: Array[String] = [
	"res://scripts/core/game_state.gd",
	"res://scripts/systems/monthly_turn_closure_policy.gd",
	"res://scripts/systems/weekly_planning_controller.gd",
	"res://scripts/systems/tournament_manager_demo_monthly.gd",
	"res://scripts/systems/economy_manager_weekly.gd",
	"res://scripts/systems/event_manager_demo.gd",
	"res://scripts/systems/rival_manager_weekly.gd",
	"res://scripts/systems/roster_manager.gd",
	"res://scripts/systems/market_manager.gd",
	"res://scripts/systems/campaign_manager_demo.gd",
	"res://scripts/systems/personality_manager_monthly.gd",
	"res://scripts/systems/relationship_manager_monthly.gd",
]
const FORBIDDEN_LEGACY_COMBAT_CALLS: Array[String] = [
	"CombatManager.",
	"combat_manager_weekly.gd",
	"combat_manager_fixed.gd",
]
const FORBIDDEN_HIDDEN_TICK_CALLS: Array[String] = [
	"GameState.advance_day()",
	"GameState.advance_week()",
	".process_day()",
	".process_week()",
	"GameState.day_advanced.connect",
	"GameState.week_advanced.connect",
	"range(DAYS_PER_WEEK)",
	"range(GameState.DAYS_PER_WEEK)",
]


func run() -> void:
	_assert_canonical_combat_cannot_call_legacy_result_authority()
	_assert_monthly_systems_cannot_schedule_hidden_ticks()
	print("Demo canonical authority quality gate: OK")


func _assert_canonical_combat_cannot_call_legacy_result_authority() -> void:
	for path in CANONICAL_COMBAT_FILES:
		var source := _source(path)
		for forbidden in FORBIDDEN_LEGACY_COMBAT_CALLS:
			assert(
				not source.contains(forbidden),
				(
					"Canonical demo combat must not reference legacy result authority '%s': %s"
					% [forbidden, path]
				),
			)

	var gt_runtime := _source("res://scripts/combat/gt1_combat_runtime.gd")
	assert(gt_runtime.contains("TournamentManager.register_grand_tournament_fight_result"))
	assert(not gt_runtime.contains("TournamentManager.register_combat_result"))
	var arena_runtime := _source("res://scripts/ui/combat_v1_arena_runtime.gd")
	assert(arena_runtime.contains('"legacy_combat_manager_allowed": false'))
	for loop_path in [
		"res://scripts/combat/combat_1v1_loop.gd",
		"res://scripts/combat/combat_1v2_loop.gd",
		"res://scripts/combat/combat_2v2_loop.gd",
	]:
		assert(_source(loop_path).contains("CombatSimulator"))


func _assert_monthly_systems_cannot_schedule_hidden_ticks() -> void:
	for path in CANONICAL_MONTHLY_FILES:
		var source := _source(path)
		for forbidden in FORBIDDEN_HIDDEN_TICK_CALLS:
			assert(
				not source.contains(forbidden),
				(
					"Canonical monthly system must not schedule hidden legacy tick '%s': %s"
					% [forbidden, path]
				),
			)

	var game_state := _source("res://scripts/core/game_state.gd")
	assert(game_state.contains('"internal_work_ticks": 1'))
	for monthly_call in [
		"RosterManager.process_month()",
		"RivalManager.process_month()",
		"EconomyManager.process_month()",
		"TournamentManager.process_month()",
		"EventManager.process_month()",
	]:
		assert(game_state.count(monthly_call) == 1)
	assert(game_state.contains("func advance_day()"))
	assert(game_state.contains("func advance_week()"))
	assert(game_state.count("advance_month()") >= 3)


func _source(path: String) -> String:
	assert(FileAccess.file_exists(path), "Quality-gate source missing: %s" % path)
	return FileAccess.get_file_as_string(path)
