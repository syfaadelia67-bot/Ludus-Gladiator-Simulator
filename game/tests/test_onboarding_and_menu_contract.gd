extends Node

const TUTORIAL_PATH := "res://scripts/ui/tutorial_controller.gd"
const OWNER_PATH := "res://scripts/systems/ludus_owner_manager.gd"
const START_SCREEN_PATH := "res://scripts/ui/start_screen_controller.gd"
const RETURN_MENU_PATH := "res://scripts/ui/main_menu_return_controller.gd"
const PROJECT_PATH := "res://project.godot"


func _ready() -> void:
	_assert_file_contains(
		TUTORIAL_PATH,
		[
			"GameState.month_advanced",
			"UniqueGladiatorManager.first_gladiator_acquired.connect",
			"RosterManager.job_assignment_changed.connect",
			"FincaHubController.system_opened.connect",
			"GameState.get_month_closure_status()",
			"initial_gladiator",
			"inspect_roster",
			"assign_work",
			"inspect_finca",
			"inspect_equipment",
			"close_month",
			"SaveManager.load_completed.connect",
			"func _restore_progress()",
			"LudusOwnerManager.get_tutorial_progress()",
			"current_step = clampi",
			"completed_objectives =",
			"func _persist_progress()",
			"LudusOwnerManager.update_tutorial_progress(current_step, completed_objectives)",
		]
	)
	_assert_file_not_contains(
		TUTORIAL_PATH,
		[
			"GameState.week_advanced",
			"CombatManager.combat_finished",
			"weekly_combat",
		]
	)
	_assert_file_contains(
		OWNER_PATH,
		[
			"tutorial_progress",
			"current_step",
			"completed_objectives",
			"func update_tutorial_progress",
			"func get_tutorial_progress",
			"func import_state",
			"func _sanitize_profile",
			"TUTORIAL_STEP_COUNT := 7",
			"TUTORIAL_OBJECTIVE_IDS",
			"initial_gladiator",
			"inspect_roster",
			"assign_work",
			"inspect_finca",
			"inspect_equipment",
			"close_month",
			"gt1_preparation",
			"func _sanitize_tutorial_objectives",
			"_onboarding_policy.sanitize_completed_objectives",
			"func get_tutorial_contract",
			'SaveManager.call_deferred("save_game")',
		]
	)
	_assert_file_not_contains(
		OWNER_PATH,
		[
			'"obtain_equipment"',
			'"resolve_event"',
			'"weekly_combat"',
		]
	)
	_assert_file_contains(
		START_SCREEN_PATH,
		[
			"func show_main_menu()",
			"func _enter_campaign()",
			"overlay.visible = false",
			"NewCampaignCoordinator.reset_campaign_state()",
		]
	)
	_assert_file_contains(
		RETURN_MENU_PATH,
		[
			"Guardar y menú",
			"SaveManager.save_game()",
			"StartScreenController.show_main_menu()",
		]
	)
	_assert_file_contains(
		PROJECT_PATH,
		['MainMenuReturnController="*res://scripts/ui/main_menu_return_controller.gd"']
	)
	print("Monthly onboarding and menu return contract: OK")
	get_tree().quit()


func _assert_file_contains(path: String, expected_fragments: Array[String]) -> void:
	assert(FileAccess.file_exists(path), "Falta el archivo requerido: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "No se pudo abrir: %s" % path)
	var source := file.get_as_text()
	file.close()
	for fragment in expected_fragments:
		assert(
			source.contains(fragment), "%s no contiene el contrato esperado: %s" % [path, fragment]
		)


func _assert_file_not_contains(path: String, forbidden_fragments: Array[String]) -> void:
	assert(FileAccess.file_exists(path), "Falta el archivo requerido: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "No se pudo abrir: %s" % path)
	var source := file.get_as_text()
	file.close()
	for fragment in forbidden_fragments:
		assert(
			not source.contains(fragment),
			"%s conserva contrato legacy prohibido: %s" % [path, fragment]
		)
