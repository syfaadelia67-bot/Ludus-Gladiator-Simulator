extends Node

const PersonScript = preload("res://scripts/entities/person.gd")

func _ready() -> void:
    var person = PersonScript.new({
        "id":"test_gladiator",
        "name":"Test",
        "role":"gladiator",
        "strength":5,
        "agility":5,
        "endurance":5,
        "intelligence":5,
        "technique":5,
        "health":50
    })

    assert(person.technique == 5, "Gladiators must start with technique")
    assert(person.health == 50, "Gladiators must start with 50 persistent health")
    assert(person.get_max_health() == 60, "Max health must combine persistent health and endurance")

    person.apply_growth({
        "strength":2,
        "agility":2,
        "endurance":2,
        "intelligence":2,
        "technique":2,
        "health":10
    })
    assert(person.strength == 7)
    assert(person.agility == 7)
    assert(person.endurance == 7)
    assert(person.intelligence == 7)
    assert(person.technique == 7)
    assert(person.health == 60)
    assert(person.get_max_health() == 74)

    _validate_growth_budgets()
    print("Person progression stats tests passed")
    get_tree().quit(0)

func _validate_growth_budgets() -> void:
    var file := FileAccess.open("res://data/specializations.json", FileAccess.READ)
    assert(file != null, "Specializations catalog must exist")
    var entries: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    assert(entries is Array)
    for raw_entry in entries:
        assert(raw_entry is Dictionary)
        var growth: Dictionary = raw_entry.get("growth_per_level", {})
        var attribute_points := int(growth.get("strength", 0)) + int(growth.get("agility", 0)) + int(growth.get("endurance", 0)) + int(growth.get("intelligence", 0)) + int(growth.get("technique", 0))
        var health_points := int(growth.get("health", 0))
        var budget := attribute_points + floori(float(health_points) / 5.0)
        assert(budget == 12, "%s growth budget must equal 12 points" % str(raw_entry.get("id", "unknown")))
