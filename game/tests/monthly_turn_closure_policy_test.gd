extends Node

const MonthlyTurnClosurePolicyScript = preload(
	"res://scripts/systems/monthly_turn_closure_policy.gd"
)


func _ready() -> void:
	var policy = MonthlyTurnClosurePolicyScript.new()
	_test_non_gt_month_closes_without_invented_combat(policy)
	_test_pending_event_blocks(policy)
	_test_gt1_incomplete_blocks(policy)
	_test_gt1_complete_allows_closure(policy)
	_test_campaign_over_blocks(policy)
	_test_contract(policy)
	print("Monthly turn closure policy: OK")
	get_tree().quit(0)


func _test_non_gt_month_closes_without_invented_combat(policy) -> void:
	var result: Dictionary = policy.evaluate(5, false, {}, {}, _summary({"13": 0, "16": 0, "20": 0}))
	assert(result.get("can_close") == true)
	assert(result.get("non_gt_combat_required") == false)
	assert(result.get("fight_pending") == false)
	assert((result.get("blockers", []) as Array).is_empty())
	var fight: Dictionary = result.get("fight", {})
	assert(fight.get("required") == false)
	assert(fight.get("name") == "Gestión del ludus")


func _test_pending_event_blocks(policy) -> void:
	var result: Dictionary = policy.evaluate(
		7,
		false,
		{"id": "monthly_event"},
		{},
		_summary({"13": 0, "16": 0, "20": 0}),
	)
	assert(result.get("can_close") == false)
	assert(_has_blocker(result, "event_pending"))


func _test_gt1_incomplete_blocks(policy) -> void:
	var result: Dictionary = policy.evaluate(
		13,
		false,
		{},
		_encounter(13),
		_summary({"13": 2, "16": 0, "20": 0}),
	)
	assert(result.get("can_close") == false)
	assert(result.get("fight_pending") == true)
	assert(_has_blocker(result, "gt1_encounter_incomplete"))
	var fight: Dictionary = result.get("fight", {})
	assert(fight.get("completed_bouts") == 2)
	assert(fight.get("required_bouts") == 3)


func _test_gt1_complete_allows_closure(policy) -> void:
	var result: Dictionary = policy.evaluate(
		13,
		false,
		{},
		_encounter(13),
		_summary({"13": 3, "16": 0, "20": 0}),
	)
	assert(result.get("can_close") == true)
	assert(result.get("fight_pending") == false)
	assert((result.get("blockers", []) as Array).is_empty())


func _test_campaign_over_blocks(policy) -> void:
	var result: Dictionary = policy.evaluate(
		20,
		true,
		{},
		_encounter(20),
		_summary({"13": 3, "16": 3, "20": 3}),
	)
	assert(result.get("can_close") == false)
	assert(_has_blocker(result, "campaign_over"))


func _test_contract(policy) -> void:
	var contract: Dictionary = policy.get_contract()
	assert(contract.get("period") == "month")
	assert(contract.get("non_gt_combat_required") == false)
	assert(contract.get("legacy_combat_schedule_allowed") == false)
	assert(contract.get("warnings_block_closure") == false)
	assert(contract.get("save_version_change_required") == false)
	assert(
		contract.get("processing_order")
		== ["roster", "rivals", "economy", "tournaments", "advance_clock", "events", "food"]
	)


func _encounter(month: int) -> Dictionary:
	return {
		"month": month,
		"tournament_name": "Gran Torneo de Roma",
		"series_bouts": 3,
	}


func _summary(progress: Dictionary) -> Dictionary:
	return {"encounter_progress": progress.duplicate(true)}


func _has_blocker(result: Dictionary, code: String) -> bool:
	for blocker in result.get("blocker_details", []) as Array:
		if blocker is Dictionary and str((blocker as Dictionary).get("code", "")) == code:
			return true
	return false
