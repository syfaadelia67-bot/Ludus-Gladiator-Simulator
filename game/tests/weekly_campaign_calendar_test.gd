extends Node

func run() -> void:
    for week in range(1, 17):
        var details: Dictionary = CombatManager.get_event_details_for_week(week)
        assert(not details.is_empty())
        assert(str(details.get("type", "none")) != "none")
        assert(str(details.get("name", "")).length() > 0)

    var finale: Dictionary = CombatManager.get_event_details_for_week(16)
    assert(str(finale.get("type", "")) == "demo_finale")
    assert(str(finale.get("name", "")) == "Combate final de la demo")
    assert(bool(finale.get("finale", false)))
    assert(str(CombatManager.get_event_type_for_week(12)) == "official")
    assert(str(CombatManager.get_event_type_for_week(15)) == "beast_hunt")

    var calendar_source := FileAccess.get_file_as_string("res://scripts/ui/weekly_calendar_presenter.gd")
    var start_source := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")
    assert(calendar_source.contains("week > DEMO_FINAL_WEEK"))
    assert(calendar_source.contains("— FINAL"))
    assert(calendar_source.contains("PREPARACIÓN PARA EL COMBATE FINAL"))
    assert(calendar_source.contains("Victorias acumuladas: %d/%d"))
    assert(calendar_source.contains("REQUIRED_FINALE_WINS := 6"))
    assert(calendar_source.contains("CampaignManager.get_summary()"))
    assert(calendar_source.contains("final_combat_resolved"))
    assert(calendar_source.contains("Entrá en Arena"))
    assert(calendar_source.contains("faltan %d victorias"))
    assert(start_source.contains("if week == 16"))
    assert(start_source.contains("Combate final de la demo"))

    print("weekly_campaign_calendar_test: OK")
