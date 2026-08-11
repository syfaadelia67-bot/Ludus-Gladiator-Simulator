extends "res://scripts/systems/campaign_manager.gd"

signal objective_failed(objective: Dictionary)

const MonthlyNonGTActivityPolicyScript = preload(
	"res://scripts/systems/monthly_non_gt_activity_policy.gd"
)
const DemoFinalePolicyScript = preload("res://scripts/systems/demo_finale_policy.gd")
const GT1RivalResultsProviderScript = preload("res://scripts/combat/gt1_rival_results_provider.gd")

var failed_objectives: Array[String] = []
var _non_gt_activity_policy = MonthlyNonGTActivityPolicyScript.new()
var _finale_policy = DemoFinalePolicyScript.new()
var _gt1_rival_results_provider = GT1RivalResultsProviderScript.new()


func _ready() -> void:
	GameState.month_advanced.connect(_on_month_advanced)
	if TournamentManager.has_signal("grand_tournament_changed"):
		TournamentManager.connect(
			"grand_tournament_changed", Callable(self, "_on_grand_tournament_changed")
		)
	_sync_approved_combat_progress()
	evaluate_progress()


func _on_grand_tournament_changed(_summary: Dictionary) -> void:
	_sync_approved_combat_progress()
	evaluate_progress()
	_evaluate_campaign_finale()


func register_gt1_rival_results(results: Array) -> Dictionary:
	var registration: Dictionary = _gt1_rival_results_provider.register_explicit_results(results)
	if registration.get("status") != "registered":
		return registration
	_sync_approved_combat_progress()
	evaluate_progress()
	_evaluate_campaign_finale()
	return registration


func get_gt1_rival_results_provider_contract() -> Dictionary:
	return _gt1_rival_results_provider.get_contract()


func evaluate_progress() -> void:
	if campaign_over:
		return
	_sync_approved_combat_progress()
	_evaluate_chapter()
	_evaluate_rank()
	_evaluate_objectives()
	campaign_changed.emit()


func _evaluate_campaign_finale() -> void:
	if campaign_over:
		return
	var finale := _finale_policy.evaluate(
		GameState.get_month(), TournamentManager.get_gt1_summary()
	)
	if not bool(finale.get("can_finalize", false)):
		return
	_apply_gt1_finale_state(finale)
	var result_message := _finale_result_message(finale)
	campaign_finished.emit(victory_achieved, result_message)
	campaign_changed.emit()


func _evaluate_objectives() -> void:
	_mark_expired_objectives()
	for objective in OBJECTIVES:
		var objective_id := str(objective.get("id", ""))
		if _non_gt_activity_policy.is_objective_retired_from_demo(objective_id):
			continue
		if completed_objectives.has(objective_id) or failed_objectives.has(objective_id):
			continue
		if GameState.get_month() > _deadline_for_objective(objective):
			_fail_objective(objective)
			continue
		if _objective_progress(objective) < int(objective.get("target", 1)):
			continue
		completed_objectives.append(objective_id)
		GameState.denarii += int(objective.get("reward_denarii", 0))
		GameState.reputation += int(objective.get("reward_reputation", 0))
		objective_completed.emit(objective.duplicate(true))
		GameState.resources_changed.emit()


func get_objectives(chapter_id: String = "") -> Array:
	var result: Array = []
	for objective in OBJECTIVES:
		var objective_id := str(objective.get("id", ""))
		if _non_gt_activity_policy.is_objective_retired_from_demo(objective_id):
			continue
		if not chapter_id.is_empty() and str(objective.get("chapter", "")) != chapter_id:
			continue
		var data: Dictionary = objective.duplicate(true)
		var deadline := _deadline_for_objective(objective)
		data["progress"] = _objective_progress(objective)
		data["completed"] = completed_objectives.has(objective_id)
		data["design_blocked"] = false
		data["available"] = true
		data["blocked_reason"] = ""
		data["failed"] = (
			failed_objectives.has(objective_id)
			or (GameState.get_month() > deadline and not bool(data["completed"]))
		)
		data["deadline_month"] = deadline
		data["months_remaining"] = maxi(0, deadline - GameState.get_month() + 1)
		# Compatibility aliases for presenters/tests that have not migrated yet.
		data["deadline_week"] = deadline
		data["weeks_remaining"] = data["months_remaining"]
		result.append(data)
	return result


func get_current_rank() -> Dictionary:
	return _decorate_rank(super.get_current_rank())


func get_next_rank() -> Dictionary:
	return _decorate_rank(super.get_next_rank())


func get_summary() -> Dictionary:
	var data := super.get_summary()
	data["approved_combat_progress_source"] = "gt1_combat_v1"
	data["non_gt_activity"] = _non_gt_activity_policy.evaluate_month(GameState.get_month())
	data["retired_demo_objectives"] = MonthlyNonGTActivityPolicyScript.RETIRED_DEMO_OBJECTIVES.duplicate()
	data["finale"] = _finale_policy.evaluate(
		GameState.get_month(), TournamentManager.get_gt1_summary()
	)
	data["gt1_rival_results_provider"] = get_gt1_rival_results_provider_contract()
	return data


func export_state() -> Dictionary:
	var data := super.export_state()
	data["failed_objectives"] = failed_objectives.duplicate()
	return data


func import_state(data: Dictionary) -> void:
	super.import_state(data)
	_reconcile_loaded_finale_state()
	failed_objectives.clear()
	for raw_id in data.get("failed_objectives", []):
		var objective_id := str(raw_id)
		if (
			_objective_exists(objective_id)
			and not _non_gt_activity_policy.is_objective_retired_from_demo(objective_id)
			and not completed_objectives.has(objective_id)
			and not failed_objectives.has(objective_id)
		):
			failed_objectives.append(objective_id)
	_sync_approved_combat_progress()
	_mark_expired_objectives()
	campaign_changed.emit()


func _reconcile_loaded_finale_state() -> void:
	var finale := _finale_policy.evaluate(
		GameState.get_month(), TournamentManager.get_gt1_summary()
	)
	var can_finalize := bool(finale.get("can_finalize", false))
	if final_combat_resolved and not can_finalize:
		# A Save v14 campaign cannot claim the GT I finale while standings or its
		# tiebreak are unresolved. Reopen the finale instead of trusting stale flags.
		final_combat_resolved = false
		campaign_over = false
		victory_achieved = false
		defeat_reason = ""
		return
	if can_finalize and (final_combat_resolved or not campaign_over):
		_apply_gt1_finale_state(finale)


func _apply_gt1_finale_state(finale: Dictionary) -> void:
	final_combat_resolved = true
	campaign_over = true
	victory_achieved = bool(finale.get("victory", false))
	defeat_reason = (
		"" if victory_achieved else "El ludus completó el Gran Torneo de Roma sin subir al podio."
	)


func _finale_result_message(finale: Dictionary) -> String:
	if not bool(finale.get("victory", false)):
		return defeat_reason
	return (
		"El ludus terminó %d.º en Roma y obtuvo medalla %s."
		% [int(finale.get("placement", 0)), _medal_label(str(finale.get("medal", "")))]
	)


func _medal_label(medal: String) -> String:
	match medal:
		"gold":
			return "oro"
		"silver":
			return "plata"
		"bronze":
			return "bronce"
		_:
			return "sin medalla"


func _mark_expired_objectives() -> void:
	for objective in OBJECTIVES:
		var objective_id := str(objective.get("id", ""))
		if _non_gt_activity_policy.is_objective_retired_from_demo(objective_id):
			continue
		if completed_objectives.has(objective_id) or failed_objectives.has(objective_id):
			continue
		if GameState.get_month() > _deadline_for_objective(objective):
			_fail_objective(objective)


func _fail_objective(objective: Dictionary) -> void:
	var objective_id := str(objective.get("id", ""))
	if (
		objective_id.is_empty()
		or completed_objectives.has(objective_id)
		or failed_objectives.has(objective_id)
		or _non_gt_activity_policy.is_objective_retired_from_demo(objective_id)
	):
		return
	failed_objectives.append(objective_id)
	var failed := objective.duplicate(true)
	var deadline := _deadline_for_objective(objective)
	failed["deadline_month"] = deadline
	failed["deadline_week"] = deadline
	objective_failed.emit(failed)


func _deadline_for_objective(objective: Dictionary) -> int:
	var chapter_id := str(objective.get("chapter", ""))
	for chapter in CHAPTERS:
		if str(chapter.get("id", "")) == chapter_id:
			return int(chapter.get("month_end", chapter.get("week_end", DEMO_FINAL_MONTH)))
	return DEMO_FINAL_MONTH


func _objective_exists(objective_id: String) -> bool:
	for objective in OBJECTIVES:
		if str(objective.get("id", "")) == objective_id:
			return true
	return false


func _sync_approved_combat_progress() -> void:
	var summary: Dictionary = TournamentManager.get_gt1_summary()
	var approved_bouts := clampi(int(summary.get("player_bouts", 0)), 0, 9)
	var approved_wins := clampi(int(summary.get("player_wins", 0)), 0, approved_bouts)
	total_wins = approved_wins
	total_losses = approved_bouts - approved_wins


func _decorate_rank(rank: Dictionary) -> Dictionary:
	if rank.is_empty():
		return {}
	var data := rank.duplicate(true)
	data["combat_progress_source"] = "gt1_combat_v1"
	data["legacy_arena_unlock_active"] = false
	data["unlock_status"] = "demo_gt1_only"
	return data
