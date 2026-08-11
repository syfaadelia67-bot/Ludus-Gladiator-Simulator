extends Node


func run() -> void:
	var tutorial := FileAccess.get_file_as_string("res://scripts/ui/tutorial_controller.gd")
	var policy := FileAccess.get_file_as_string("res://scripts/systems/monthly_onboarding_policy.gd")
	var owner := FileAccess.get_file_as_string("res://scripts/systems/ludus_owner_manager.gd")
	var roster := FileAccess.get_file_as_string("res://scripts/systems/roster_manager.gd")
	var selection := FileAccess.get_file_as_string(
		"res://scripts/ui/initial_gladiator_selection_presenter.gd"
	)
	var save_manager := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")

	assert(tutorial.contains("MonthlyOnboardingPolicyScript"))
	assert(tutorial.contains("UniqueGladiatorManager.first_gladiator_acquired.connect"))
	assert(tutorial.contains("GameState.month_advanced.connect"))
	assert(tutorial.contains("RosterManager.job_assignment_changed.connect"))
	assert(tutorial.contains("GameState.get_month_closure_status()"))
	assert(tutorial.contains('"initial_gladiator"'))
	assert(tutorial.contains('"close_month"'))
	assert(not tutorial.contains("GameState.week_advanced.connect"))
	assert(not tutorial.contains("CombatManager.combat_finished.connect"))

	assert(policy.contains('"initial_gladiator"'))
	assert(policy.contains('"inspect_roster"'))
	assert(policy.contains('"assign_work"'))
	assert(policy.contains('"inspect_finca"'))
	assert(policy.contains('"inspect_equipment"'))
	assert(policy.contains('"close_month"'))
	assert(policy.contains('"gt1_preparation"'))
	assert(policy.contains("const GT1_MONTHS: Array[int] = [13, 16, 20]"))
	assert(policy.contains('"advance_week": "close_month"'))
	assert(policy.contains('"legacy_week_advance_allowed": false'))
	assert(policy.contains('"legacy_combat_completion_allowed": false'))
	assert(policy.contains('"mandatory_non_gt_combat_taught": false'))
	assert(policy.contains('"save_version_change_required": false'))

	assert(owner.contains("TUTORIAL_STEP_COUNT := 7"))
	assert(owner.contains("_onboarding_policy.sanitize_completed_objectives"))
	assert(owner.contains("get_tutorial_contract"))
	assert(roster.contains("signal job_assignment_changed(person_id: String, job_id: String)"))
	assert(roster.contains("job_assignment_changed.emit(person_id, job_id)"))

	assert(selection.contains("_canonical_combat_stats_text"))
	assert(selection.contains('source.get("resistance", 5)'))
	assert(selection.contains('source.get("technique", 5)'))
	assert(not selection.contains('"INT %d'))
	assert(not selection.contains('int(offer.get("endurance", 5))'))

	assert(save_manager.contains("SAVE_VERSION remains 14"))
	assert(save_manager.contains('game_data["week"] = month'))
	print("Monthly onboarding integration contract: OK")
