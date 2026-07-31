extends Node

func _ready() -> void:
    var presenter := FileAccess.get_file_as_string("res://scripts/ui/completed_campaign_read_only_presenter.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(presenter.contains("CampaignManager.campaign_changed.connect"))
    assert(presenter.contains("SaveManager.load_completed.connect"))
    assert(presenter.contains("CAMPAÑA FINALIZADA · MODO CONSULTA"))
    assert(presenter.contains("CampaignManager.campaign_over"))
    assert(presenter.contains("button.disabled = read_only"))
    assert(presenter.contains("LOCKED_TOOLTIP"))

    for control_path in [
        "Margin/VBox/TopButtons/AdvanceDay",
        "Margin/VBox/TopButtons/RefreshMarket",
        "Margin/VBox/Tabs/Mercado/BuyOffer",
        "Margin/VBox/Tabs/Forja/ForgePanel/CraftItem",
        "Margin/VBox/Tabs/Arena/Setup/StartDuel"
    ]:
        assert(presenter.contains(control_path))

    assert(not presenter.contains("CombatLog"))
    assert(not presenter.contains("Inventory"))
    assert(not presenter.contains("WeeklyCalendar"))
    assert(project.contains("CompletedCampaignReadOnlyPresenter=\"*res://scripts/ui/completed_campaign_read_only_presenter.gd\""))
    assert(project.find("CampaignResultPresenter=") < project.find("CompletedCampaignReadOnlyPresenter="))
    assert(project.find("CompletedCampaignReadOnlyPresenter=") < project.find("StartScreenController="))

    print("Completed campaign read-only UI contract: OK")
    get_tree().quit()
