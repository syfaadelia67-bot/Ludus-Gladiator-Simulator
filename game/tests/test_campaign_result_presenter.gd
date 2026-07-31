extends Node

func _ready() -> void:
    var presenter := FileAccess.get_file_as_string("res://scripts/ui/campaign_result_presenter.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(presenter.contains("CampaignManager.campaign_finished.connect"))
    assert(presenter.contains("SaveManager.load_completed.connect"))
    assert(presenter.contains("campaign_over"))
    assert(presenter.contains("victory"))
    assert(presenter.contains("defeat_reason"))
    assert(presenter.contains("VICTORIA DE CAMPAÑA"))
    assert(presenter.contains("CAMPAÑA FINALIZADA"))
    assert(presenter.contains("Victorias"))
    assert(presenter.contains("Derrotas"))
    assert(presenter.contains("Rango final"))
    assert(presenter.contains("Objetivos"))
    assert(presenter.contains("Guardar y volver al menú principal"))
    assert(presenter.contains("SaveManager.save_game()"))
    assert(presenter.contains("StartScreenController.show_main_menu()"))
    assert(project.contains("CampaignResultPresenter=\"*res://scripts/ui/campaign_result_presenter.gd\""))
    assert(project.find("CampaignManager=") < project.find("CampaignResultPresenter="))
    assert(project.find("CampaignResultPresenter=") < project.find("StartScreenController="))

    print("Campaign result presenter contract: OK")
    get_tree().quit()
