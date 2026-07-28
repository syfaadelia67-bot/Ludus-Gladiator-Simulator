extends Node

signal combat_finished(result: Dictionary)
signal combat_failed(reason: String)
signal combat_turn(action: Dictionary)

const TACTICS: Dictionary = {
    "balanced": "Equilibrada",
    "aggressive": "Agresiva",
    "defensive": "Defensiva",
    "careful": "Cuidadosa"
}

const TECHNIQUES: Dictionary = {
    "basic_attack": {"name":"Ataque básico","energy":10,"power":1.0,"accuracy":0,"cooldown":0,"description":"Golpe seguro."},
    "guard": {"name":"Guardia","energy":6,"power":0.0,"accuracy":0,"cooldown":1,"description":"Reduce el siguiente daño."},
    "feint": {"name":"Finta","energy":12,"power":0.82,"accuracy":16,"cooldown":2,"description":"Mejora la precisión."},
    "lunge": {"name":"Estocada","energy":16,"power":1.35,"accuracy":-5,"cooldown":2,"bleed":2,"description":"Puede provocar sangrado."},
    "shield_bash": {"name":"Golpe con escudo","energy":14,"power":0.75,"accuracy":4,"cooldown":3,"stun":1,"description":"Puede aturdir."},
    "disarm": {"name":"Desarmar","energy":18,"power":0.55,"accuracy":-8,"cooldown":4,"weaken":4,"description":"Reduce el ataque rival."},
    "sunder": {"name":"Romper armadura","energy":18,"power":0.90,"accuracy":-4,"cooldown":4,"armor_break":5,"description":"Reduce la defensa rival."},
    "warcry": {"name":"Grito de guerra","energy":8,"power":0.0,"accuracy":0,"cooldown":4,"attack_buff":4,"description":"Aumenta el ataque."},
    "throw_sand": {"name":"Arrojar arena","energy":10,"power":0.35,"accuracy":12,"cooldown":4,"blind":15,"description":"Reduce la precisión rival."},
    "execute": {"name":"Ejecución","energy":24,"power":1.85,"accuracy":-12,"cooldown":5,"finisher":true,"description":"Remate contra rivales heridos."}
}

var last_result: Dictionary = {}
var last_combat_day: int = -1
var next_battle_config: Dictionary = {
    "energy_rule":"balanced",
    "surrender_threshold":20,
    "allow_finisher":true,
    "techniques":["basic_attack","guard","feint"]
}

func get_tactic_ids() -> Array[String]:
    var result: Array[String] = []
    for value: Variant in TACTICS.keys():
        result.append(str(value))
    return result

func get_tactic_name(tactic_id: String) -> String:
    return str(TACTICS.get(tactic_id, tactic_id.capitalize()))

func get_technique_ids() -> Array[String]:
    var result: Array[String] = []
    for value: Variant in TECHNIQUES.keys():
        result.append(str(value))
    return result

func get_technique(technique_id: String) -> Dictionary:
    return TECHNIQUES.get(technique_id, {}).duplicate(true)

func configure_next_battle(config: Dictionary) -> void:
    next_battle_config = next_battle_config.merged(config, true)

func get_current_event_type() -> String:
    if GameState.day % 7 == 0:
        return "official"
    if GameState.day % 3 == 0:
        return "underground"
    return "none"

func get_current_event_name() -> String:
    var event_type: String = get_current_event_type()
    if event_type == "official":
        return "Torneo oficial de la arena"
    if event_type == "underground":
        return "Combate clandestino del bajo mundo"
    return "No hay combates programados hoy"

func get_current_event_details() -> Dictionary:
    var event_type: String = get_current_event_type()
    if event_type == "official":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Duelo reglamentado.","risk":"Heridas moderadas","reward":"Denarios + reputación","team_size":1}
    if event_type == "underground":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Sin árbitros.","risk":"Heridas graves","reward":"Más denarios","team_size":1}
    return {"type":"none","name":get_current_event_name(),"rules":get_next_event_summary(),"risk":"Sin combate","reward":"—","team_size":0}

func get_next_event_summary() -> String:
    var next_underground: int = GameState.day + (3 - GameState.day % 3)
    var next_official: int = GameState.day + (7 - GameState.day % 7)
    return "Próximo clandestino: día %d. Próximo oficial: día %d." % [next_underground, next_official]

func simulate_duel(gladiator_id: String, tactic: String = "balanced") -> Dictionary:
    var event_type: String = get_current_event_type()
    if event_type == "none":
        combat_failed.emit("Hoy no hay combates. %s" % get_next_event_summary())
        return {}
    if last_combat_day == GameState.day:
        combat_failed.emit("El ludus ya combatió hoy.")
        return {}
    var fighter: Variant = RosterManager.get_person(gladiator_id)
    if fighter == null or fighter.role != "gladiator":
        combat_failed.emit("Seleccioná un gladiador válido.")
        return {}
    if not fighter.is_available_for_combat():
        combat_failed.emit("El gladiador no está disponible.")
        return {}

    var player: Dictionary = _build_combatant(fighter, tactic)
    var enemy: Dictionary = _build_enemy(fighter, event_type)
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.randomize()
    var actions: Array[Dictionary] = []
    var combat_log: Array[String] = []
    var round_value: int = 0
    var surrendered: bool = false

    actions.append(_snapshot("intro", 0, "%s contra %s" % [player.name, enemy.name], player, enemy, "", "system"))
    while int(player.health) > 0 and int(enemy.health) > 0 and round_value < 30:
        round_value += 1
        _apply_bleeding(player, enemy, actions, round_value, true)
        _apply_bleeding(enemy, player, actions, round_value, false)
        if int(player.health) <= 0 or int(enemy.health) <= 0:
            break
        _attack(player, enemy, rng, actions, combat_log, round_value, true)
        if int(enemy.health) <= 0:
            break
        _attack(enemy, player, rng, actions, combat_log, round_value, false)
        if _should_surrender(fighter, player, tactic, rng):
            surrendered = true
            actions.append(_snapshot("surrender", round_value, "%s se rinde" % fighter.display_name, player, enemy, "surrender", "player"))
            break
        player.energy = mini(int(player.max_energy), int(player.energy) + _energy_regeneration())
        enemy.energy = mini(int(enemy.max_energy), int(enemy.energy) + 6)

    var victory: bool = int(enemy.health) <= 0 and int(player.health) > 0 and not surrendered
    var reward: int = 0
    var reputation: int = 0
    if victory:
        reward = int(round((70 + int(enemy.attack) * 3) * (1.35 if event_type == "underground" else 1.0)))
        reputation = 0 if event_type == "underground" else 3
        GameState.denarii += reward
        GameState.reputation += reputation
    fighter.fatigue = mini(100, fighter.fatigue + 8 + round_value / 2)
    var injury: String = _resolve_injury(fighter, player, victory, surrendered, rng, event_type)
    PersonalityManager.register_combat_result(fighter, victory, surrendered, fighter.injury_severity)
    EconomyManager.register_combat_result(victory)
    var tournament_result: Dictionary = {}
    if event_type == "official":
        tournament_result = TournamentManager.register_combat_result(fighter.id, victory)

    actions.append(_snapshot("result", round_value, "VICTORIA" if victory else ("RENDICIÓN" if surrendered else "DERROTA"), player, enemy, "", "system"))
    last_combat_day = GameState.day
    last_result = {
        "event_type":event_type,"event_name":get_current_event_name(),"victory":victory,"surrendered":surrendered,
        "rounds":round_value,"fighter":fighter.display_name,"fighter_id":fighter.id,"enemy":enemy.name,"tactic":tactic,
        "player_health":maxi(0,int(player.health)),"player_max_health":int(player.max_health),"player_energy":maxi(0,int(player.energy)),"player_max_energy":int(player.max_energy),
        "enemy_health":maxi(0,int(enemy.health)),"enemy_max_health":int(enemy.max_health),"enemy_energy":maxi(0,int(enemy.energy)),"enemy_max_energy":int(enemy.max_energy),
        "reward":reward,"reputation":reputation,"injury":injury,"injury_days":fighter.injury_days,"tournament":tournament_result,
        "actions":actions,"technique_stats":_summarize_techniques(actions),"status_stats":_summarize_statuses(actions),"log":combat_log
    }
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    combat_finished.emit(last_result)
    return last_result

func _build_combatant(person: Variant, tactic: String) -> Dictionary:
    var equipment: Dictionary = EquipmentManager.get_equipped_stats(person)
    var progression: Dictionary = GladiatorProgressionManager.get_modifiers(person.id)
    var attack: int = int(round(person.get_base_attack() + int(equipment.get("power", 0)) + int(progression.get("attack_bonus", 0))))
    var defense: int = int(round(person.get_base_defense() + int(equipment.get("defense", 0)) + int(progression.get("defense_bonus", 0))))
    var accuracy: int = 55 + int(person.agility) * 3 + int(progression.get("accuracy_bonus", 0))
    if tactic == "aggressive":
        attack = int(attack * 1.18)
        defense = int(defense * 0.86)
    elif tactic == "defensive":
        defense = int(defense * 1.24)
        attack = int(attack * 0.90)
    elif tactic == "careful":
        accuracy += 12
    var techniques: Array = next_battle_config.get("techniques", ["basic_attack"])
    return {"name":person.display_name,"health":person.get_max_health(),"max_health":person.get_max_health(),"energy":person.get_max_energy(),"max_energy":person.get_max_energy(),"attack":attack,"defense":defense,"accuracy":accuracy,"techniques":techniques,"cooldowns":{},"bleeding":0,"blind":0,"armor_break":0,"attack_buff":0}

func _build_enemy(person: Variant, event_type: String) -> Dictionary:
    var tier: int = maxi(1, floori(float(person.strength + person.agility + person.endurance) / 8.0)) + (1 if event_type == "official" else 0)
    return {"name":("Campeón oficial" if event_type == "official" else "Luchador clandestino") + " nivel %d" % tier,"health":78+tier*20,"max_health":78+tier*20,"energy":72+tier*9,"max_energy":72+tier*9,"attack":15+tier*5,"defense":8+tier*4,"accuracy":58+tier*3,"techniques":["basic_attack","guard","feint","lunge"],"cooldowns":{},"bleeding":0,"blind":0,"armor_break":0,"attack_buff":0}

func _attack(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator, actions: Array[Dictionary], combat_log: Array[String], round_value: int, player_attacks: bool) -> void:
    var technique_id: String = _choose_technique(attacker, defender)
    var technique: Dictionary = get_technique(technique_id)
    var cost: int = int(technique.get("energy", 10))
    if int(attacker.energy) < cost:
        attacker.energy = mini(int(attacker.max_energy), int(attacker.energy) + 14)
        actions.append(_oriented_snapshot("recover", round_value, "%s recupera energía." % attacker.name, attacker, defender, "recover", player_attacks))
        return
    attacker.energy = int(attacker.energy) - cost
    if technique_id == "guard":
        attacker.defense = int(attacker.defense) + 4
        actions.append(_oriented_snapshot("guard", round_value, "%s adopta guardia." % attacker.name, attacker, defender, technique_id, player_attacks))
        return
    if technique_id == "warcry":
        attacker.attack_buff = int(attacker.get("attack_buff", 0)) + 4
        actions.append(_oriented_snapshot("buff", round_value, "%s lanza un grito de guerra." % attacker.name, attacker, defender, technique_id, player_attacks))
        return
    var hit_chance: int = clampi(int(attacker.accuracy) + int(technique.get("accuracy", 0)) - int(attacker.get("blind", 0)), 18, 96)
    if rng.randi_range(1, 100) > hit_chance:
        actions.append(_oriented_snapshot("miss", round_value, "%s falla %s." % [attacker.name, technique.get("name", technique_id)], attacker, defender, technique_id, player_attacks))
        return
    var damage: int = maxi(1, int(round((int(attacker.attack) + int(attacker.get("attack_buff", 0))) * float(technique.get("power", 1.0)))) - int(defender.defense) / 2)
    defender.health = int(defender.health) - damage
    if int(technique.get("bleed", 0)) > 0:
        defender.bleeding = maxi(int(defender.get("bleeding", 0)), int(technique.get("bleed", 0)))
    if int(technique.get("armor_break", 0)) > 0:
        defender.defense = maxi(0, int(defender.defense) - int(technique.get("armor_break", 0)))
    if int(technique.get("weaken", 0)) > 0:
        defender.attack = maxi(1, int(defender.attack) - int(technique.get("weaken", 0)))
    if int(technique.get("blind", 0)) > 0:
        defender.blind = int(technique.get("blind", 0))
    var action: Dictionary = _oriented_snapshot("hit", round_value, "%s usa %s y causa %d de daño." % [attacker.name, technique.get("name", technique_id), damage], attacker, defender, technique_id, player_attacks)
    action["damage"] = damage
    action["applied_status"] = _status_from_technique(technique)
    actions.append(action)
    combat_log.append(str(action.text))

func _choose_technique(attacker: Dictionary, defender: Dictionary) -> String:
    var available: Array = attacker.get("techniques", ["basic_attack"])
    var enemy_ratio: float = float(maxi(0, int(defender.health))) / float(maxi(1, int(defender.max_health)))
    var self_ratio: float = float(maxi(0, int(attacker.health))) / float(maxi(1, int(attacker.max_health)))
    if available.has("execute") and enemy_ratio <= 0.25 and bool(next_battle_config.get("allow_finisher", true)):
        return "execute"
    if available.has("guard") and self_ratio <= 0.35:
        return "guard"
    if available.has("sunder") and int(defender.defense) > int(attacker.attack) / 2:
        return "sunder"
    if available.has("lunge") and enemy_ratio <= 0.55:
        return "lunge"
    return str(available[randi_range(0, available.size() - 1)]) if not available.is_empty() else "basic_attack"

func _apply_bleeding(combatant: Dictionary, opponent: Dictionary, actions: Array[Dictionary], round_value: int, player_side: bool) -> void:
    if int(combatant.get("bleeding", 0)) <= 0:
        return
    var damage: int = maxi(1, int(combatant.max_health) / 30)
    combatant.health = int(combatant.health) - damage
    combatant.bleeding = maxi(0, int(combatant.bleeding) - 1)
    var action: Dictionary = _oriented_snapshot("status_damage", round_value, "%s pierde %d por sangrado." % [combatant.name, damage], combatant, opponent, "bleeding", player_side)
    action["damage"] = damage
    action["applied_status"] = "sangrado"
    actions.append(action)

func _should_surrender(fighter: Variant, player: Dictionary, tactic: String, rng: RandomNumberGenerator) -> bool:
    var threshold: int = int(next_battle_config.get("surrender_threshold", 20))
    if threshold <= 0 or int(player.health) <= 0:
        return false
    var health_percent: int = floori(100.0 * float(player.health) / float(maxi(1, int(player.max_health))))
    if health_percent > threshold:
        return false
    var chance: int = 35 + maxi(0, 45 - int(fighter.morale))
    if tactic == "aggressive":
        chance -= 14
    elif tactic == "careful":
        chance += 8
    return rng.randi_range(1, 100) <= clampi(chance, 8, 88)

func _energy_regeneration() -> int:
    var rule: String = str(next_battle_config.get("energy_rule", "balanced"))
    if rule == "conserve":
        return 9
    if rule == "spend":
        return 4
    return 6

func _resolve_injury(fighter: Variant, player: Dictionary, victory: bool, surrendered: bool, rng: RandomNumberGenerator, event_type: String) -> String:
    var health_ratio: float = float(maxi(0, int(player.health))) / float(maxi(1, int(player.max_health)))
    var chance: int = 10 + (10 if event_type == "underground" else 0)
    if health_ratio <= 0.0:
        chance = 80
    elif health_ratio < 0.25:
        chance += 42
    if surrendered:
        chance -= 15
    if victory:
        chance -= 4
    if rng.randi_range(1, 100) > clampi(chance, 2, 92):
        return ""
    var severity: int = 2 if health_ratio < 0.25 else 1
    var injury_name: String = "Herida profunda" if severity == 2 else "Contusión"
    var days: int = severity * 2 + rng.randi_range(0, severity * 2)
    fighter.apply_injury(injury_name, severity, days)
    return "%s; recuperación: %d día(s)" % [injury_name, days]

func _snapshot(type_id: String, round_value: int, text: String, player: Dictionary, enemy: Dictionary, technique: String, actor: String) -> Dictionary:
    return {"type":type_id,"round":round_value,"text":text,"technique":technique,"actor":actor,"player_health":maxi(0,int(player.health)),"player_max_health":int(player.max_health),"player_energy":maxi(0,int(player.energy)),"player_max_energy":int(player.max_energy),"enemy_health":maxi(0,int(enemy.health)),"enemy_max_health":int(enemy.max_health),"enemy_energy":maxi(0,int(enemy.energy)),"enemy_max_energy":int(enemy.max_energy)}

func _oriented_snapshot(type_id: String, round_value: int, text: String, attacker: Dictionary, defender: Dictionary, technique: String, player_attacks: bool) -> Dictionary:
    var player: Dictionary = attacker if player_attacks else defender
    var enemy: Dictionary = defender if player_attacks else attacker
    return _snapshot(type_id, round_value, text, player, enemy, technique, "player" if player_attacks else "enemy")

func _status_from_technique(technique: Dictionary) -> String:
    if int(technique.get("bleed", 0)) > 0: return "sangrado"
    if int(technique.get("stun", 0)) > 0: return "aturdimiento"
    if int(technique.get("armor_break", 0)) > 0: return "armadura rota"
    if int(technique.get("blind", 0)) > 0: return "ceguera"
    if int(technique.get("weaken", 0)) > 0: return "desarme"
    return ""

func _summarize_techniques(actions: Array[Dictionary]) -> Dictionary:
    var stats: Dictionary = {}
    for action: Dictionary in actions:
        if str(action.get("actor", "")) != "player": continue
        var technique_id: String = str(action.get("technique", ""))
        if technique_id.is_empty() or not TECHNIQUES.has(technique_id): continue
        if not stats.has(technique_id): stats[technique_id] = {"name":get_technique(technique_id).get("name", technique_id),"uses":0,"damage":0}
        stats[technique_id]["uses"] = int(stats[technique_id]["uses"]) + 1
        stats[technique_id]["damage"] = int(stats[technique_id]["damage"]) + int(action.get("damage", 0))
    return stats

func _summarize_statuses(actions: Array[Dictionary]) -> Dictionary:
    var stats: Dictionary = {}
    for action: Dictionary in actions:
        var status: String = str(action.get("applied_status", ""))
        if not status.is_empty(): stats[status] = int(stats.get(status, 0)) + 1
    return stats
