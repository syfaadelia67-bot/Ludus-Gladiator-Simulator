extends Node


func run() -> void:
	var presenter := FileAccess.get_file_as_string("res://scripts/ui/campaign_result_presenter.gd")
	var localization := FileAccess.get_file_as_string("res://localization/shared.es.po")
	var project := FileAccess.get_file_as_string("res://project.godot")

	assert(presenter.contains("CampaignManager.campaign_finished.connect"))
	assert(presenter.contains("SaveManager.load_completed.connect"))
	assert(presenter.contains("campaign_over"))
	assert(presenter.contains("victory"))
	assert(presenter.contains("defeat_reason"))
	assert(presenter.contains("CAMPAIGN_RESULT_TITLE_VICTORY"))
	assert(presenter.contains("CAMPAIGN_RESULT_TITLE_FINISHED"))
	assert(presenter.contains("CAMPAIGN_RESULT_DETAILS"))
	assert(presenter.contains("CAMPAIGN_RESULT_GT1"))
	assert(presenter.contains('finale.get("placement", 0)'))
	assert(presenter.contains('finale.get("medal", "")'))
	assert(presenter.contains("CAMPAIGN_RESULT_READ_ONLY_BUTTON"))
	assert(presenter.contains("CAMPAIGN_RESULT_RETURN_MENU_BUTTON"))
	assert(presenter.contains("SaveManager.save_game()"))
	assert(presenter.contains("StartScreenController.show_main_menu()"))

	for localized_text in [
		"VICTORIA DE CAMPAÑA",
		"CAMPAÑA FINALIZADA",
		"Victorias GT I",
		"Derrotas GT I",
		"Rango final",
		"Objetivos",
		"Continuar en modo consulta",
		"Guardar y volver al menú principal",
	]:
		assert(localization.contains(localized_text))

	assert(project.contains('CampaignResultPresenter="*res://scripts/ui/campaign_result_presenter.gd"'))
	assert(project.find("CampaignManager=") < project.find("CampaignResultPresenter="))
	assert(project.find("CampaignResultPresenter=") < project.find("StartScreenController="))

	print("Localized GT I campaign result presenter contract: OK")
