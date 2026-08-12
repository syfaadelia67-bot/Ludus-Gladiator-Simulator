extends SceneTree


func _initialize() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var scene := FileAccess.get_file_as_string("res://scenes/ArenaScreen.tscn")
	var monthly_scene := FileAccess.get_file_as_string("res://scenes/ArenaScreenMonthly.tscn")
	var controller := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
	var monthly_controller := FileAccess.get_file_as_string("res://scripts/ui/arena_screen_monthly.gd")
	var runtime := FileAccess.get_file_as_string("res://scripts/ui/combat_v1_arena_runtime.gd")
	var bootstrap := FileAccess.get_file_as_string("res://scripts/ui/main_ui_bootstrap.gd")
	var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")

	assert(project.contains("window/size/viewport_width=1920"))
	assert(project.contains("window/size/viewport_height=1080"))
	assert(project.contains('window/stretch/mode="canvas_items"'))
	assert(project.contains('window/stretch/aspect="expand"'))

	for required_node in [
		"RosterPanel",
		"CenterPanel",
		"EncounterPanel",
		"RosterList",
		"ArenaVisual",
		"Battlefield",
		"PlayerFighter",
		"EnemyFighter",
		"PreparationView",
		"ResultView",
		"StartCombat",
		"ViewResult",
		"BackToPreparation",
		"ResultSummary",
		"CombatLog",
		"BackToFinca",
	]:
		assert(
			(
				scene.contains('name="%s"' % required_node)
				or scene.contains('name = "%s"' % required_node)
			)
		)

	assert(scene.contains('[node name="Body" type="HBoxContainer"'))
	assert(not scene.contains("HSplitContainer"))
	assert(scene.count('type="ScrollContainer"') == 3)
	assert(scene.contains("Body/RosterPanel/Margin/Scroll"))
	assert(scene.contains("Body/CenterPanel/Margin/Scroll"))
	assert(scene.contains("Body/EncounterPanel/Margin/Scroll"))

	assert(controller.contains("begin_gt1_session"))
	assert(controller.contains("advance_exchange_with_ai_requests"))
	assert(controller.contains("_arena_runtime.build_snapshot"))
	assert(controller.contains('FincaHubController.open_system("equipamiento")'))
	assert(not controller.contains("CombatManager"))
	assert(not controller.contains("simulate_duel"))
	assert(runtime.contains('"combat_authority": "combat_simulator"'))
	assert(runtime.contains('"scoring_authority": "tournament_manager"'))
	assert(monthly_scene.contains("arena_tournament_presentation_guard.gd"))
	assert(monthly_controller.contains("_start_non_gt_contract"))
	assert(monthly_controller.contains("_series_setup_panel.visible = has_tournament_of_mars"))

	assert(hub.contains('"arena": "res://scenes/ArenaScreenMonthly.tscn"'))
	assert(hub.contains('"torneos": "res://scenes/TournamentsPanelMonthly.tscn"'))
	assert(hub.contains("var packed := load(scene_path) as PackedScene"))
	assert(bootstrap.contains("FincaHubController.prepare_scene()"))
	assert(not bootstrap.contains("CombatManager."))

	assert(load("res://scenes/ArenaScreen.tscn") is PackedScene)
	assert(load("res://scenes/ArenaScreenMonthly.tscn") is PackedScene)
	assert(load("res://scripts/ui/arena_screen.gd") != null)
	assert(load("res://scripts/ui/arena_screen_monthly.gd") != null)
	print("Arena three-column monthly Combat V1 routed flow contract: OK")
	quit()
