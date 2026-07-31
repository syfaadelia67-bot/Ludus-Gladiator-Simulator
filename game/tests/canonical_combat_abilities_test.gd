extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var manager = CombatManager

    var precise_i: Dictionary = manager.get_ability("precise_strike", 1)
    var precise_ii: Dictionary = manager.get_ability("precise_strike", 2)
    assert(str(precise_i.get("name", "")) == "Golpe preciso", "Combat must load canonical abilities")
    assert(int(precise_ii.get("accuracy_bonus", 0)) > int(precise_i.get("accuracy_bonus", 0)), "Level II must improve the ability")

    var attacker := manager._combatant_base("Player", "gladiator", 100, 100, 30, 15, 90, {
        "throw_sand":1,
        "opportunity_strike":1,
        "precise_strike":2
    }, [
        {"ability_id":"opportunity_strike", "condition":"target_vulnerable"},
        {"ability_id":"throw_sand", "condition":"opening"},
        {"ability_id":"precise_strike", "condition":"always"}
    ])
    var defender := manager._combatant_base("Enemy", "gladiator", 100, 100, 20, 10, 60, {}, [])

    assert(manager._choose_ability(attacker, defender, 1) == "throw_sand", "Opening order must be selected on round one")
    defender.vulnerable = true
    assert(manager._choose_ability(attacker, defender, 2) == "opportunity_strike", "Vulnerable target order must take priority")
    defender.vulnerable = false
    assert(manager._choose_ability(attacker, defender, 2) == "precise_strike", "Always order must be the tactical fallback")

    assert(manager._condition_matches("self_low_health", attacker, defender, 2) == false, "Healthy combatant must not match low health")
    attacker.health = 30
    assert(manager._condition_matches("self_low_health", attacker, defender, 2), "Low health condition must activate at 35 percent")

    var sand: Dictionary = manager.get_ability("throw_sand", 2)
    var rng := RandomNumberGenerator.new()
    rng.seed = 1
    sand["blind_chance"] = 1.0
    manager._apply_ability_effects(sand, attacker, defender, rng)
    assert(int(defender.get("blind", 0)) > 0, "Throw sand must apply blindness")
    assert(bool(defender.get("vulnerable", false)), "Blindness must make the target tactically vulnerable")

    var dance: Dictionary = manager.get_ability("dance_of_two_blades", 2)
    assert(int(dance.get("hits", 0)) == 2, "Dimachaerus class ability must execute two hits")
    assert(float(dance.get("damage_multiplier_per_hit", 0.0)) > 0.0, "Class ability must expose level scaling")

    print("Canonical combat abilities and tactical plan tests passed")
    quit(0)
