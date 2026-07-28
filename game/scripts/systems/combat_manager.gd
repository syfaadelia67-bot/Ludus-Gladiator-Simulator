extends Node

signal combat_finished(result: Dictionary)
signal combat_failed(reason: String)

const TACTICS := {
    "balanced": "Equilibrada",
    "aggressive": "Agresiva",
    "defensive": "Defensiva",
    "careful": "Cuidadosa"
}

var last_result: Dictionary = {}

func get_tactic_ids() -> Array[String]:
    var result: Array[String] = []
    for tactic_id in TACTICS.keys():
        result.append(str(tactic_id))
    return result

func get_tactic_name(tactic_id: String) -> String:
    return str(TACTICS.get(tactic_id, tactic_id.capitalize()))

func simulate_duel(gladiator_id: String, tactic: String = "balanced") -> Dictionary:
    var fighter = RosterManager.get_person(gladiator_id)
    if fighter == null or fighter.role != "gladiator":
        combat_failed.emit("Seleccioná un gladiador válido.")
        return {}
    if not fighter.is_available_for_combat():
        combat_failed.emit("El gladiador está herido o demasiado fatigado.")
        return {}
    if not TACTICS.has(tactic):
        combat_failed.emit("La táctica seleccionada no existe.")
        return {}

    var enemy := _generate_enemy(fighter)
    var player := _build_combatant(fighter, tactic)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var combat_log: Array[String] = []
    var round := 0
    var surrendered := false
    var relationship_bonus := RelationshipManager.get_combat_morale_bonus(fighter.id)

    combat_log.append("%s entra a la arena con táctica %s." % [fighter.display_name, get_tactic_name(tactic)])
    if relationship_bonus > 0:
        combat_log.append("El apoyo y la rivalidad de sus compañeros fortalecen su determinación.")
    elif relationship_bonus < 0:
        combat_log.append("Las enemistades dentro del ludus pesan sobre su ánimo.")
    while player.health > 0 and enemy.health > 0 and round < 30:
        round += 1
        combat_log.append("--- Ronda %d ---" % round)
        _perform_attack(player, enemy, rng, combat_log)
        if enemy.health <= 0:
            break
        _perform_attack(enemy, player, rng, combat_log)
        if _should_surrender(fighter, player, tactic, rng):
            surrendered = true
            combat_log.append("%s arroja el arma y se rinde." % fighter.display_name)
            break
        player.energy = mini(player.max_energy, player.energy + 5)
        enemy.energy = mini(enemy.max_energy, enemy.energy + 5)

    var victory := enemy.health <= 0 and player.health > 0 and not surrendered
    var reward := 0
    var reputation := 0
    var injury := _resolve_injury(fighter, player, victory, surrendered, rng)
    fighter.fatigue = mini(100, fighter.fatigue + 8 + round / 2)

    if victory:
        reward = int(round((70 + enemy.attack * 3) * float(player.get("reward_multiplier", 1.0))))
        reputation = 2 + enemy.defense / 8
        GameState.denarii += reward
        GameState.reputation += reputation
        fighter.morale = mini(100, fighter.morale + 8 + maxi(0, relationship_bonus))
        combat_log.append("%s obtiene la victoria." % fighter.display_name)
    elif surrendered:
        fighter.morale = maxi(0, fighter.morale - 6 + relationship_bonus)
        GameState.reputation = maxi(0, GameState.reputation - 1)
        combat_log.append("La rendición preserva su vida, pero daña la reputación del ludus.")
    else:
        fighter.morale = maxi(0, fighter.morale - 10 + relationship_bonus)
        combat_log.append("%s pierde el combate." % fighter.display_name)

    if not injury.is_empty():
        combat_log.append("Consecuencia: %s." % injury)

    var personality_event := PersonalityManager.register_combat_result(fighter, victory, surrendered, fighter.injury_severity)
    if not str(personality_event.get("description", "")).is_empty():
        combat_log.append("Reacción: %s" % personality_event.get("description", ""))

    EconomyManager.register_combat_result(victory)
    var tournament_result := TournamentManager.register_combat_result(fighter.id, victory)
    if not tournament_result.is_empty():
        if victory:
            combat_log.append("Contrato cumplido: +%d denarios adicionales." % int(tournament_result.get("reward_paid", 0)))
        else:
            combat_log.append("Contrato de combate perdido: reputación %d." % int(tournament_result.get("reputation_change", 0)))

    last_result = {
        "victory": victory,
        "surrendered": surrendered,
        "rounds": round,
        "fighter": fighter.display_name,
        "fighter_id": fighter.id,
        "enemy": enemy.name,
        "tactic": tactic,
        "player_health": maxi(0, player.health),
        "player_max_health": player.max_health,
        "player_energy": maxi(0, player.energy),
        "player_max_energy": player.max_energy,
        "enemy_health": maxi(0, enemy.health),
        "enemy_max_health": enemy.max_health,
        "enemy_energy": maxi(0, enemy.energy),
        "enemy_max_energy": enemy.max_energy,
        "player_attack": player.attack,
        "player_defense": player.defense,
        "enemy_attack": enemy.attack,
        "enemy_defense": enemy.defense,
        "reward": reward,
        "reputation": reputation,
        "injury": injury,
        "injury_days": fighter.injury_days,
        "tournament": tournament_result,
        "personality": personality_event,
        "relationship_bonus": relationship_bonus,
        "log": combat_log
    }
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    combat_finished.emit(last_result)
    return last_result

func _should_surrender(fighter, player: Dictionary, tactic: String, rng: RandomNumberGenerator) -> bool:
    if player.health <= 0:
        return false
    var health_ratio := float(player.health) / float(maxi(1, player.max_health))
    if health_ratio > 0.28:
        return false
    var personality := PersonalityManager.get_combat_modifiers(fighter.id, fighter.traits)
    var relationship_bonus := RelationshipManager.get_combat_morale_bonus(fighter.id)
    var chance := 20 + maxi(0, 45 - fighter.morale) + fighter.fatigue / 5 + int(personality.get("surrender", 0)) - relationship_bonus
    if tactic == "aggressive": chance -= 12
    if tactic == "careful": chance += 8
    if fighter.traits.has("arena_lover"): chance -= 8
    if fighter.traits.has("freedom_seeker"): chance += 5
    return rng.randi_range(1, 100) <= clampi(chance, 5, 80)

func _resolve_injury(fighter, player: Dictionary, victory: bool, surrendered: bool, rng: RandomNumberGenerator) -> String:
    var health_ratio := float(maxi(0, player.health)) / float(maxi(1, player.max_health))
    var chance := 8
    if health_ratio <= 0.0: chance = 75
    elif health_ratio < 0.25: chance = 48
    elif health_ratio < 0.50: chance = 24
    if surrendered: chance -= 18
    if victory: chance -= 5
    chance -= EstateManager.get_level("infirmary") * 2
    var personality := PersonalityManager.get_combat_modifiers(fighter.id, fighter.traits)
    chance = int(round(chance * float(personality.get("injury_risk", 1.0))))
    if rng.randi_range(1, 100) > clampi(chance, 2, 90):
        return ""
    var severity := 1
    if health_ratio <= 0.0 or rng.randi_range(1, 100) <= 18: severity = 3
    elif health_ratio < 0.25 or rng.randi_range(1, 100) <= 42: severity = 2
    var names := {
        1: ["Contusión", "Corte superficial", "Esguince"],
        2: ["Herida profunda", "Costilla fisurada", "Luxación"],
        3: ["Fractura grave", "Trauma severo", "Herida crítica"]
    }
    var pool: Array = names[severity]
    var injury_name := str(pool[rng.randi_range(0, pool.size() - 1)])
    var days := severity * 2 + rng.randi_range(0, severity * 2)
    fighter.apply_injury(injury_name, severity, days)
    return "%s; recuperación estimada: %d día(s)" % [injury_name, days]

func _build_combatant(person, tactic: String) -> Dictionary:
    var equipment := EquipmentManager.get_equipped_stats(person)
    var progression := GladiatorProgressionManager.get_modifiers(person.id)
    var personality := PersonalityManager.get_combat_modifiers(person.id, person.traits)
    var relationship_bonus := RelationshipManager.get_combat_morale_bonus(person.id)
    var relationship_multiplier := 1.0 + float(relationship_bonus) * 0.01
    var attack := int(round((person.get_base_attack() + int(equipment.get("power", 0)) + int(progression.get("attack_bonus", 0))) * float(progression.get("attack", 1.0)) * float(personality.get("attack", 1.0)) * relationship_multiplier))
    var defense := int(round((person.get_base_defense() + int(equipment.get("defense", 0)) + int(progression.get("defense_bonus", 0))) * float(progression.get("defense", 1.0)) * float(personality.get("defense", 1.0)) * relationship_multiplier))
    var max_health := int(round(person.get_max_health() * float(progression.get("health", 1.0))))
    var max_energy := int(round((person.get_max_energy() + int(progression.get("energy_bonus", 0)) + maxi(0, relationship_bonus)) * float(progression.get("energy", 1.0))))
    var accuracy := 55 + person.agility * 3 + int(progression.get("accuracy_bonus", 0)) + int(personality.get("accuracy", 0)) + relationship_bonus
    var energy_cost := 12
    match tactic:
        "aggressive":
            attack = int(attack * 1.20)
            defense = int(defense * 0.85)
            energy_cost = 16
        "defensive":
            defense = int(defense * 1.25)
            attack = int(attack * 0.90)
            energy_cost = 9
        "careful":
            accuracy += 12
            attack = int(attack * 0.92)
            energy_cost = 10
    return {
        "name": person.display_name,
        "health": max_health,
        "max_health": max_health,
        "energy": max_energy,
        "max_energy": max_energy,
        "attack": attack,
        "defense": defense,
        "accuracy": accuracy,
        "energy_cost": energy_cost,
        "reward_multiplier": float(progression.get("reward_multiplier", 1.0))
    }

func _generate_enemy(person) -> Dictionary:
    var tier := maxi(1, (person.strength + person.agility + person.endurance) / 8)
    return {
        "name": "Gladiador rival nivel %d" % tier,
        "health": 75 + tier * 20,
        "max_health": 75 + tier * 20,
        "energy": 70 + tier * 8,
        "max_energy": 70 + tier * 8,
        "attack": 15 + tier * 5,
        "defense": 8 + tier * 4,
        "accuracy": 58 + tier * 3,
        "energy_cost": 12
    }

func _perform_attack(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator, combat_log: Array[String]) -> void:
    if attacker.energy < attacker.energy_cost:
        attacker.energy = mini(attacker.max_energy, attacker.energy + 12)
        combat_log.append("%s recupera energía." % attacker.name)
        return
    attacker.energy -= attacker.energy_cost
    if rng.randi_range(1, 100) > int(attacker.accuracy):
        combat_log.append("%s falla el ataque." % attacker.name)
        return
    var variance := rng.randi_range(-3, 4)
    var damage := maxi(1, int(attacker.attack) + variance - int(defender.defense) / 2)
    defender.health -= damage
    combat_log.append("%s causa %d de daño a %s." % [attacker.name, damage, defender.name])
