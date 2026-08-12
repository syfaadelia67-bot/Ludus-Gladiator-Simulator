extends Node


func _ready() -> void:
	var hud_bootstrap := FileAccess.get_file_as_string("res://scripts/ui/main_ui_bootstrap.gd")
	var hub := FileAccess.get_file_as_string("res://scripts/ui/finca_hub_controller.gd")
	var arena_screen := FileAccess.get_file_as_string("res://scripts/ui/arena_screen.gd")
	var event_modal := FileAccess.get_file_as_string(
		"res://scripts/ui/weekly_event_modal_presenter.gd"
	)
	var mastery := FileAccess.get_file_as_string(
		"res://scripts/systems/specialization_mastery_controller.gd"
	)
	var dossier_panel := FileAccess.get_file_as_string(
		"res://scripts/ui/gladiator_dossier_panel.gd"
	)
	var dossier_facade := FileAccess.get_file_as_string(
		"res://scripts/ui/gladiator_dossier_presenter.gd"
	)
	var project := FileAccess.get_file_as_string("res://project.godot")

	assert(hud_bootstrap.contains("FincaHubController.prepare_scene()"))
	assert(hud_bootstrap.contains("_open_finca_as_primary_view"))
	assert(hub.contains('"arena": "res://scenes/ArenaScreen.tscn"'))
	assert(hub.contains('"gladiator_dossier": "res://scenes/GladiatorDossierPanel.tscn"'))
	assert(hub.contains("func _show_hosted_screen"))
	assert(hub.contains("func open_gladiator_dossier("))
	assert(arena_screen.contains("BackToFinca"))
	assert(arena_screen.contains("FincaHubController.show_finca()"))
	assert(arena_screen.contains('FincaHubController.open_system("personal")'))
	assert(arena_screen.contains("ui_cancel"))
	assert(arena_screen.contains("CombatV1ArenaRuntimeScript"))
	assert(arena_screen.contains("_arena_runtime.build_snapshot"))
	assert(not arena_screen.contains("CombatManager"))

	assert(event_modal.contains("MonthlyEventModal"))
	assert(event_modal.contains("set_tab_hidden"))
	assert(event_modal.contains("El mes no puede continuar sin una decisión"))
	assert(event_modal.contains("Continuar en la finca"))
	assert(event_modal.contains("EventManager.resolve_choice"))
	assert(not event_modal.contains("La semana no puede continuar sin una decisión"))

	assert(mastery.contains("specialization_progress"))
	assert(mastery.contains("MAX_PROGRESS := 100"))
	assert(mastery.contains("VICTORY_BONUS"))
	assert(mastery.contains("register_training_use"))
	assert(mastery.contains("func _compatible_equipment_bonus"))
	assert(mastery.contains("EquipmentManager.get_equipped_tags(person)"))

	assert(dossier_panel.contains('"information": "INFORMACIÓN"'))
	assert(dossier_panel.contains('"equipment": "EQUIPAMIENTO"'))
	assert(dossier_panel.contains('"skills": "HABILIDADES"'))
	assert(dossier_panel.contains('"traits": "RASGOS"'))
	assert(dossier_panel.contains('"specialization": "ESPECIALIZACIÓN"'))
	assert(dossier_panel.contains("func open_gladiator("))
	assert(dossier_panel.contains("GladiatorProgressionManager.get_record"))
	assert(dossier_panel.contains("EquipmentManager.get_equipped_stats"))
	assert(dossier_panel.contains("Pack000Assets.get_texture"))

	assert(dossier_facade.contains("Compatibility facade only."))
	assert(dossier_facade.contains("FincaHubController.open_gladiator_dossier(person_id)"))
	assert(not dossier_facade.contains("_attach_when_ready"))
	assert(not dossier_facade.contains("ROSTER_LIST_PATH"))

	assert(project.contains('AllTabsUIBootstrap="*res://scripts/ui/main_ui_bootstrap.gd"'))
	assert(not project.contains("all_tabs_ui_bootstrap.gd"))
	assert(project.contains("SpecializationMasteryController="))
	assert(project.contains("GladiatorDossierPresenter="))
	assert(not project.contains("ArenaOpponentPreviewPresenter="))
	assert(not project.contains("ArenaFinaleWarningPresenter="))

	print("Hosted monthly Combat V1 visual flow corrections contract: OK")
	get_tree().quit()
