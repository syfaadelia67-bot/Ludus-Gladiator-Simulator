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
var last_combat_day: int = -1

func get_tactic_ids() -> Array[String]:
    var result: Array[String] = []
    for tactic_id in TACTICS.keys():
        result.append(str(tactic_id))
    return result

func get_tactic_name(tactic_id: String) -> String:
    return str(TACTICS.get(tactic_id, tactic_id.capitalize()))

func get_current_event_type() -> String:
    if GameState.day % 7 == 0:
        return "official"
    if GameState.day % 3 == 0:
        return "underground"
    return "none"

func get_current_event_name() -> String:
    match get_current_event_type():
        "official": return "Torneo oficial de la arena"
        "underground": return "Combate clandestino del bajo mundo"
        _: return "No hay combates programados hoy"

func get_next_event_summary() -> String:
    if get_current_event_type() != "none":
        return get_current_event_name()
    var next_underground: int = GameState.day + (3 - GameState.day % 3)
    var next_official: int = GameState.day + (7 - GameState.day % 7)
    return "Próximo combate clandestino: día %d. Próximo torneo oficial: día %d." % [next_underground, next_official]

func simulate_duel(gladiator_id: String, tactic: String = "balanced") -> Dictionary:
    var event_type: String = get_current_event_type()
    if event_type == "none":
        combat_failed.emit("Hoy no hay combates. %s" % get_next_event_summary())
        return {}
    if last_combat_day == GameState.day:
        combat_failed.emit("El ludus ya participó en un combate durante el día %d." % GameState.day)
        return {}
    var fighter = RosterManager.get_person(gladiator_id)
    if fighter == null or fighter.role != "gladiator":
        combat_failed.emit("Solo un gladiador puede ser inscrito en la arena.")
        return {}
    if not fighter.is_available_for_combat():
        combat_failed.emit("El gladiador está herido o demasiado fatigado.")
        return {}
    if not TACTICS.has(tactic):
        combat_failed.emit("La táctica seleccionada no existe.")
        return {}

    var enemy: Dictionary = _generate_enemy(fighter, event_type)
    var player: Dictionary = _build_combatant(fighter, tactic)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var combat_log: Array[String] = []
    var round: int = 0
    var surrendered: bool = false
    var relationship_bonus: int = RelationshipManager.get_combat_morale_bonus(fighter.id)

    combat_log.append("[b]%s — Día %d[/b]" % [get_current_event_name(), GameState.day])
    combat_log.append("%s entra al combate con táctica %s." % [fighter.display_name, get_tactic_name(tactic)])
    if event_type == "official":
        combat_log.append("El combate es oficial: otorga reputación y puede cumplir contratos de torneo.")
    else:
        combat_log.append("La pelea es clandestina: paga más denarios, pero no otorga prestigio oficial.")
    if relationship_bonus > 0:
        combat_log.append("El apoyo de sus compañeros fortalece su determinación.")
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

    var victory: bool = enemy.health <= 0 and player.health > 0 and not surrendered
    var reward: int = 0
    var reputation: int = 0
    var injury: String = _resolve_injury(fighter, player, victory, surrendered, rng)
    fighter.fatigue = mini(100, fighter.fatigue + 8 + floori(float(round) / 2.0))

    if victory:
        var base_reward: int = 70 + int(enemy.attack) * 3
        var event_multiplier: float = 1.35 if event_type == "underground" else 1.0
        reward = int(round(base_reward * event_multiplier * float(player.get("reward_multiplier", 1.0))))
        reputation = 0 if event_type == "underground" else 2 + floori(float(int(enemy.defense)) / 8.0)
        GameState.denarii += reward
        GameState.reputation += reputation
        fighter.morale = mini(100, fighter.morale + 8 + maxi(0, relationship_bonus))
        combat_log.append("%s obtiene la victoria." % fighter.display_name)
    elif surrendered:
        fighter.morale = maxi(0, fighter.morale - 6 + relationship_bonus)
        if event_type == "official":
            GameState.reputation = maxi(0, GameState.reputation - 1)
        combat_log.append("La rendición preserva su vida.")
    else:
        fighter.morale = maxi(0, fighter.morale - 10 + relationship_bonus)
        combat_log.append("%s pierde el combate." % fighter.display_name)

    if not injury.is_empty():
        combat_log.append("Consecuencia: %s." % injury)

    var personality_event: Dictionary = PersonalityManager.register_combat_result(fighter, victory, surrendered, fighter.injury_severity)
    if not str(personality_event.get("description", "")).is_empty():
        combat_log.append("Reacción: %s" % personality_event.get("description", ""))

    EconomyManager.register_combat_result(victory)
    var tournament_result: Dictionary = {}
    if event_type == "official":
        tournament_result = TournamentManager.register_combat_result(fighter.id, victory)
        if not tournament_result.is_empty():
            if victory:
                combat_log.append("Contrato oficial cumplido: +%d denarios adicionales." % int(tournament_result.get("reward_paid", 0)))
            else:
                combat_log.append("Contrato oficial perdido: reputación %d." % int(tournament_result.get("reputation_change", 0)))

    last_combat_day = GameState.day
    last_result = {
        "event_type": event_type,
        "event_name": get_current_event_name(),
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
    var health_ratio: float = float(player.health) / float(maxi(1, player.max_health))
    if health_ratio > 0.28:
        return false
    var personality: Dictionary = PersonalityManager.get_combat_modifiers(fighter.id, fighter.traits)
    var relationship_bonus: int = RelationshipManager.get_combat_morale_bonus(fighter.id)
    var chance: int = 20 + maxi(0, 45 - fighter.morale) + floori(float(fighter.fatigue) / 5.0) + int(personality.get("surrender", 0)) - relationship_bonus
    if tactic == "aggressive": chance -= 12
    if tactic == "careful": chance += 8
    if fighter.traits.has("arena_lover"): chance -= 8
    if fighter.traits.has("freedom_seeker"): chance += 5
    return rng.randi_range(1, 100) <= clampi(chance, 5, 80)

func _resolve_injury(fighter, player: Dictionary, victory: bool, surrendered: bool, rng: RandomNumberGenerator) -> String:
    var health_ratio: float = float(maxi(0, player.health)) / float(maxi(1, player.max_health))
    var chance: int = 8
    if health_ratio <= 0.0: chance = 75
    elif health_ratio < 0.25: chance = 48
    elif health_ratio < 0.50: chance = 24
    if surrendered: chance -= 18
    if victory: chance -= 5
    chance -= EstateManager.get_level("infirmary") * 2
    var personality: Dictionary = PersonalityManager.get_combat_modifiers(fighter.id, fighter.traits)
    chance = int(round(chance * float(personality.get("injury_risk", 1.0))))
    if rng.randi_range(1, 100) > clampi(chance, 2, 90):
        return ""
    var severity: int = 1
    if health_ratio <= 0.0 or rng.randi_range(1, 100) <= 18: severity = 3
    elif health_ratio < 0.25 or rng.randi_range(1, 100) <= 42: severity = 2
    var names: Dictionary = {
        1: ["Contusión", "Corte superficial", "Esguince"],
        2: ["Herida profunda", "Costilla fisurada", "Luxación"],
        3: ["Fractura grave", "Trauma severo", "Herida crítica"]
    }
    var pool: Array = names[severity]
    var injury_name: String = str(pool[rng.randi_range(0, pool.size() - 1)])
    var days: int = severity * 2 + rng.randi_range(0, severity * 2)
    fighter.apply_injury(injury_name, severity, days)
    return "%s; recuperación estimada: %d día(s)" % [injury_name, days]

func _build_combatant(person, tactic: String) -> Dictionary:
    var equipment: Dictionary = EquipmentManager.get_equipped_stats(person)
    var progression: Dictionary = GladiatorProgressionManager.get_modifiers(person.id)
    var personality: Dictionary = PersonalityManager.get_combat_modifiers(person.id, person.traits)
    var relationship_bonus: int = RelationshipManager.get_combat_morale_bonus(person.id)
    var relationship_multiplier: float = 1.0 + float(relationship_bonus) * 0.01
    var attack: int = int(round((person.get_base_attack() + int(equipment.get("power", 0)) + int(progression.get("attack_bonus", 0))) * float(progression.get("attack", 1.0)) * float(personality.get("attack", 1.0)) * relationship_multiplier))
    var defense: int = int(round((person.get_base_defense() + int(equipment.get("defense", 0)) + int(progression.get("defense_bonus", 0))) * float(progression.get("defense", 1.0)) * float(personality.get("defense", 1.0)) * relationship_multiplier))
    var max_health: int = int(round(person.get_max_health() * float(progression.get("health", 1.0))))
    var max_energy: int = int(round((person.get_max_energy() + int(progression.get("energy_bonus", 0)) + maxi(0, relationship_bonus)) * float(progression.get("energy", 1.0))))
    var accuracy: int = 55 + person.agility * 3 + int(progression.get("accuracy_bonus", 0)) + int(personality.get("accuracy", 0)) + relationship_bonus
    var energy_cost: int = 12
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

func _generate_enemy(person, event_type: String) -> Dictionary:
    var tier: int = maxi(1, floori(float(person.strength + person.agility + person.endurance) / 8.0))
    if event_type == "official":
        tier += 1
    return {
        "name": ("Campeón oficial" if event_type == "official" else "Luchador clandestino") + " nivel %d" % tier,
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
    var variance: int = rng.randi_range(-3, 4)
    var damage: int = maxi(1, int(attacker.attack) + variance - floori(float(int(defender.defense)) / 2.0))
    defender.health -= damage
    combat_log.append("%s causa %d de daño a %s." % [attacker.name, damage, defender.name])
