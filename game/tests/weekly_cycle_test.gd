extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var previous_week := GameState.day
    var previous_combat_week := CombatManager.last_combat_day

    for week in range(1, 13):
        GameState.day = week
        var event_type := CombatManager.get_current_event_type()
        assert(event_type in ["exhibition", "underground", "beast_hunt", "official"], "Every campaign week must schedule a canonical fight")
        var details: Dictionary = CombatManager.get_current_event_details()
        assert(str(details.get("type", "none")) != "none", "No week may be left without a fight")
        assert(int(details.get("team_size", 0)) >= 1, "Every weekly fight must accept at least one gladiator")

    GameState.day = 1
    assert(GameState.get_week() == 1, "The visible campaign must begin in week one")
    assert(GameState.DAYS_PER_WEEK == 7, "One player turn must represent seven internal days")

    GameState.day = previous_week
    CombatManager.last_combat_day = previous_combat_week
    print("Weekly cycle tests passed")
    quit(0)
