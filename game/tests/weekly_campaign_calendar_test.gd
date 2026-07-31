extends Node

func run() -> void:
    for week in range(1, 17):
        var details: Dictionary = CombatManager.get_event_details_for_week(week)
        assert(not details.is_empty())
        assert(str(details.get("type", "none")) != "none")
    print("weekly_campaign_calendar_test: OK")
