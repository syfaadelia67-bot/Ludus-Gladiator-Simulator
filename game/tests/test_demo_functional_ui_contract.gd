extends Node

const FunctionalUiStatePolicyScript = preload("res://scripts/ui/demo_functional_ui_state_policy.gd")


func run() -> void:
	var policy = FunctionalUiStatePolicyScript.new()
	var contract := policy.get_contract()
	var route_ids := contract.get("route_ids", []) as Array
	var supported_states := contract.get("supported_states", []) as Array
	var expected_routes: Array[String] = [
		"finca",
		"barracks",
		"bestias",
		"mercado",
		"arena",
		"equipamiento",
		"personal",
		"forja",
		"gladiator_dossier",
		"campana",
		"eventos",
		"rivales",
		"economia",
		"torneos",
		"progresion",
		"personalidad",
		"relaciones",
		"transferencias",
		"historial",
	]
	for route_id in expected_routes:
		assert(route_ids.has(route_id), "Missing functional route: %s" % route_id)
		assert(
			FincaHubController.SCREEN_SCENES.has(route_id),
			"Missing ScreenHost route: %s" % route_id
		)
		var scene_path := str(FincaHubController.SCREEN_SCENES.get(route_id, ""))
		assert(ResourceLoader.exists(scene_path), "Missing placeholder scene: %s" % scene_path)
	for state_id in ["ready", "empty", "blocked", "error", "completed_read_only"]:
		assert(supported_states.has(state_id), "Missing UI state: %s" % state_id)

	assert(bool(contract.get("presentation_only", false)))
	assert(not bool(contract.get("gameplay_authority", true)))
	assert(not bool(contract.get("final_art_required", true)))
	assert(not bool(contract.get("save_version_change_required", true)))
	var missing_route_state := policy.evaluate("missing_route")
	assert(str(missing_route_state.get("state", "")) == "error")
	assert(not bool(missing_route_state.get("blocks_navigation", true)))

	var project := FileAccess.get_file_as_string("res://project.godot")
	var presenter := FileAccess.get_file_as_string(
		"res://scripts/ui/demo_functional_ui_presenter.gd"
	)
	var localization := FileAccess.get_file_as_string("res://localization/shared.es.po")
	var start_screen := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")
	assert(
		project.contains(
			'DemoFunctionalUiPresenter="*res://scripts/ui/demo_functional_ui_presenter.gd"'
		)
	)
	assert(project.contains('window/stretch/mode="canvas_items"'))
	assert(project.contains('window/stretch/aspect="expand"'))
	assert(project.contains("window/size/viewport_width=1920"))
	assert(project.contains("window/size/viewport_height=1080"))
	assert(presenter.contains('BANNER_NAME := "FunctionalStateBanner"'))
	assert(presenter.contains('contract["state_banner_parent"] = "active_hosted_screen"'))
	assert(presenter.contains('screen.add_child(_banner)'))
	assert(not presenter.contains('host.add_child(_banner)'))
	assert(presenter.contains("control.grab_focus()"))
	assert(presenter.contains("control.focus_mode != Control.FOCUS_ALL"))
	assert(presenter.contains("_try_initialize_for_main"))
	assert(presenter.contains("_get_main_scene() == null"))
	for key in [
		"UI_STATE_LABEL_EMPTY",
		"UI_STATE_LABEL_BLOCKED",
		"UI_STATE_LABEL_ERROR",
		"UI_STATE_LABEL_READ_ONLY",
		"UI_STATE_BLOCKED_ARENA_NON_GT",
		"UI_STATE_BLOCKED_ARENA_RIVAL_DATA",
		"UI_STATE_COMPLETED_READ_ONLY",
	]:
		assert(localization.contains('msgid "%s"' % key), "Missing ES localization key: %s" % key)
	assert(not start_screen.contains("BATTLE_BEAST_HUNT"))
	assert(not start_screen.contains("BATTLE_UNDERGROUND"))
	assert(start_screen.contains("TournamentManager.get_gt1_encounter(month)"))

	print("Demo functional UI state contract: OK")
