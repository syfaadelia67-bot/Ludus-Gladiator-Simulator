extends Node

func _ready() -> void:
    _validate_weekly_event_contract()
    print("Weekly event panel contract: OK")
    get_tree().quit()

func _validate_weekly_event_contract() -> void:
    assert(EventManager.has_method("process_week"))
    assert(EventManager.has_method("get_pending_event"))
    assert(EventManager.has_method("get_active_effects"))
    assert(EventManager.has_method("get_history"))
    assert(EventManager.has_method("resolve_choice"))
    assert(GameState.has_method("get_week"))
    assert(CampaignManager.has_method("get_chapter_for_week"))

    for event_id in EventManager.EVENTS.keys():
        var event: Dictionary = EventManager.EVENTS[event_id]
        assert(not str(event.get("title", "")).is_empty())
        assert(event.get("choices", []) is Array)
        assert(event.get("choices", []).size() >= 2)
        assert(event.get("chapters", []) is Array)
        assert(not event.get("chapters", []).is_empty())
        assert(int(event.get("cooldown_weeks", 0)) >= 1)
        for choice in event.get("choices", []):
            assert(choice is Dictionary)
            assert(not str(choice.get("id", "")).is_empty())
            assert(not str(choice.get("label", "")).is_empty())
            var timed = choice.get("effects", {}).get("timed", {})
            if timed is Dictionary and not timed.is_empty():
                assert(int(timed.get("weeks", 0)) >= 1)
                assert(not timed.has("days"))
