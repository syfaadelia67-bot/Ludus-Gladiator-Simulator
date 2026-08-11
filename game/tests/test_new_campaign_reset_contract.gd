extends Node


func _ready() -> void:
	var coordinator := FileAccess.get_file_as_string(
		"res://scripts/core/new_campaign_coordinator.gd"
	)
	var save_manager := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")
	var start_screen := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")
	var project := FileAccess.get_file_as_string("res://project.godot")

	assert(coordinator.contains("func reset_campaign_state()"))
	assert(coordinator.contains("var reset_in_progress: bool = false"))
	assert(coordinator.contains("if reset_in_progress:"))
	assert(coordinator.contains("Ya se está preparando una nueva campaña."))
	assert(coordinator.contains("SaveManager.autosave_enabled = false"))
	assert(coordinator.contains("SaveManager.delete_save()"))
	assert(coordinator.contains("CombatV1SessionStore.clear_all()"))
	assert(coordinator.contains('"month": 1'))
	assert(coordinator.contains('"day": 1'))
	assert(coordinator.contains('"week": 1'))
	assert(coordinator.contains("DataRepository.get_economy_rule"))
	assert(coordinator.contains('starting_resources.get("denarii", 0)'))
	assert(coordinator.contains('"people": []'))
	assert(coordinator.contains('"owned_beasts": {"entries": []}'))
	assert(coordinator.contains('"combat_v1_runtime": {}'))
	assert(coordinator.contains('"combat_history": {"entries": []}'))
	assert(coordinator.contains("SaveManager._apply_payload(reset_payload)"))
	assert(coordinator.contains("SaveManager.autosave_enabled = previous_autosave"))
	assert(coordinator.contains("reset_in_progress = false"))
	assert(save_manager.contains('payload["owned_beasts"] = OwnedBeastRegistry.export_state()'))
	assert(
		save_manager.contains('payload["combat_v1_runtime"] = CombatV1SessionStore.export_state()')
	)
	assert(save_manager.contains("CombatV1SessionStore.import_state"))
	assert(save_manager.contains("OwnedBeastRegistry.import_state"))

	assert(start_screen.contains("NewCampaignCoordinator.reset_campaign_state()"))
	assert(
		(
			start_screen.find("NewCampaignCoordinator.reset_campaign_state()")
			< start_screen.find("LudusOwnerManager.configure_owner")
		)
	)
	assert(
		project.contains('NewCampaignCoordinator="*res://scripts/core/new_campaign_coordinator.gd"')
	)
	assert(
		project.contains('CombatV1SessionStore="*res://scripts/systems/combat_v1_session_store.gd"')
	)
	assert(project.contains('OwnedBeastRegistry="*res://scripts/systems/owned_beast_registry.gd"'))
	assert(project.find("SaveManager=") < project.find("NewCampaignCoordinator="))
	assert(project.find("TournamentManager=") < project.find("CombatV1SessionStore="))

	print("New campaign reset contract: OK")
	get_tree().quit()
