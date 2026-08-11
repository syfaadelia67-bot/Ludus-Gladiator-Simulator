extends Node

const SetupRuntime = preload("res://scripts/ui/gt1_series_setup_runtime.gd")
const RIVALS := ["rival_heavy", "rival_agile", "rival_technical"]
const PLAYER_20 := [["p1", "p2"], ["p1", "p3"], ["p1", "p3"]]
const RIVAL_20 := [
	["rival_heavy", "rival_agile"],
	["rival_heavy", "rival_technical"],
	["rival_agile", "rival_technical"],
]


func run() -> void:
	DataRepository.load_all()
	var runtime = SetupRuntime.new()
	_assert_contract(runtime)
	_assert_catalogs(runtime)
	_assert_requests(runtime)
	_assert_fail_closed(runtime)
	print("GT I series setup runtime: OK")


func _assert_contract(runtime) -> void:
	var contract := runtime.get_contract()
	assert(contract.get("setup_authority") == "gt1_series_setup_runtime")
	assert(contract.get("combat_runtime") == "combat_v1_arena_runtime")
	assert(contract.get("human_opponent_selection_authority") == "gt1_rival_combat_snapshot_provider")
	assert(contract.get("rival_catalog") == "DataRepository.rival_combat_v1_snapshots")
	assert(contract.get("month_16_beast_catalog") == "DataRepository.beasts")
	assert(contract.get("explicit_series_selection_required") == true)
	assert(contract.get("generated_opponents_allowed") == false)
	assert(contract.get("save_version_change_required") == false)


func _assert_catalogs(runtime) -> void:
	var month_13 := runtime.get_gt1_setup_catalog(13)
	assert(month_13.get("status") == "ready")
	assert(month_13.get("opponent_modes") == ["human"])
	assert((month_13.get("rivals", []) as Array).size() == 7)
	for raw_rival in month_13.get("rivals", []) as Array:
		assert(((raw_rival as Dictionary).get("fighters", []) as Array).size() == 3)
	var month_16 := runtime.get_gt1_setup_catalog(16)
	assert(month_16.get("opponent_modes") == ["human", "beast"])
	assert((month_16.get("beasts", []) as Array).size() == 3)
	var month_20 := runtime.get_gt1_setup_catalog(20)
	assert(int(month_20.get("player_slots", 0)) == 6)
	assert(int(month_20.get("opponent_slots", 0)) == 6)


func _assert_requests(runtime) -> void:
	var month_13 := runtime.prepare_month_13_request("player", "alpha", "cassianus", RIVALS)
	assert(month_13.get("status") == "ready")
	assert(month_13.get("player_ids_by_bout") == [["player"], ["player"], ["player"]])
	var month_16 := runtime.prepare_month_16_human_request(
		["p1", "p2", "p3"], "alpha", "flavianus", RIVALS
	)
	assert(month_16.get("status") == "ready")
	assert(month_16.get("independent_bouts") == true)
	var month_20 := runtime.prepare_month_20_request(PLAYER_20, "alpha", "drusus", RIVAL_20)
	assert(month_20.get("status") == "ready")
	assert(month_20.get("substitution_used") == true)
	assert((month_20.get("opponent_fighters_by_bout", []) as Array).size() == 3)


func _assert_fail_closed(runtime) -> void:
	var missing := RIVALS.duplicate()
	missing[1] = ""
	var rejected := runtime.prepare_month_13_request("player", "alpha", "cassianus", missing)
	assert(rejected.get("status") == "rejected")
	assert(rejected.get("generated_opponents_allowed") == false)
	var unknown := runtime.prepare_month_16_human_request(
		["p1", "p2", "p3"], "alpha", "unknown_ludus", RIVALS
	)
	assert(unknown.get("status") == "rejected")
	assert(runtime.get_gt1_setup_catalog(12).get("status") == "rejected")
