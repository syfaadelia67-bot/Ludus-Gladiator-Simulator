extends SceneTree

const HudStatusSnapshotScript = preload("res://scripts/ui/hud_status_snapshot.gd")

func _init() -> void:
    _test_normal_snapshot()
    _test_attention_alerts()
    _test_safe_defaults()
    print("HudStatusSnapshot tests passed")
    quit(0)

func _test_normal_snapshot() -> void:
    var snapshot: Dictionary = HudStatusSnapshotScript.build(
        {"day": 12, "denarii": 740, "food": 60, "ore": 18, "reputation": 24},
        {
            "people_count": 10,
            "daily_food_consumption": 10,
            "active_gladiators": 4,
            "gladiator_capacity": 8,
            "security": 31,
            "intelligence": 7
        },
        {"total_debt": 0},
        {"next_combat_days": 3}
    )

    assert(snapshot.day == 12)
    assert(snapshot.food_days == 6)
    assert(snapshot.active_gladiators == 4)
    assert(snapshot.gladiator_capacity == 8)
    assert(snapshot.alerts.is_empty())

func _test_attention_alerts() -> void:
    var snapshot: Dictionary = HudStatusSnapshotScript.build(
        {"day": 4, "denarii": 100, "food": 12, "ore": 0, "reputation": -3},
        {
            "people_count": 6,
            "daily_food_consumption": 6,
            "active_gladiators": 5,
            "gladiator_capacity": 5
        },
        {"total_debt": 240},
        {"next_combat_days": 1}
    )

    assert(snapshot.food_days == 2)
    assert(snapshot.alerts.size() == 4)
    assert(snapshot.alerts[0].id == "food_critical")
    assert(snapshot.alerts[1].id == "gladiator_capacity")
    assert(snapshot.alerts[2].id == "outstanding_debt")
    assert(snapshot.alerts[3].id == "combat_imminent")

func _test_safe_defaults() -> void:
    var snapshot: Dictionary = HudStatusSnapshotScript.build({})

    assert(snapshot.day == 1)
    assert(snapshot.denarii == 0)
    assert(snapshot.food == 0)
    assert(snapshot.food_days == 0)
    assert(snapshot.active_gladiators == 0)
    assert(snapshot.gladiator_capacity == 0)
    assert(snapshot.alerts.size() == 1)
    assert(snapshot.alerts[0].id == "food_critical")
