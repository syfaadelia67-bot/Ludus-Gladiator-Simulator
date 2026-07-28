extends Node

signal combat_finished(result: Dictionary)
signal combat_failed(reason: String)
signal combat_turn(action: Dictionary)

const TACTICS := {
    "balanced": "Equilibrada",
    "aggressive": "Agresiva",
    "defensive": "Defensiva",
    "careful": "Cuidadosa"
}

const TECHNIQUES := {
    "basic_attack": {"name":"Ataque básico","energy":10,"weight":28,"power":1.00,"accuracy":0,"cooldown":0,"description":"Golpe seguro sin efectos especiales."},
    "guard": {"name":"Guardia","energy":6,"weight":14,"power":0.0,"accuracy":0,"cooldown":1,"description":"Reduce el daño del siguiente ataque."},
    "feint": {"name":"Finta","energy":12,"weight":12,"power":0.82,"accuracy":16,"cooldown":2,"description":"Engaña la defensa y mejora la precisión."},
    "lunge": {"name":"Estocada","energy":16,"weight":11,"power":1.35,"accuracy":-5,"cooldown":2,"description":"Ataque potente que consume más energía."},
    "shield_bash": {"name":"Golpe con escudo","energy":14,"weight":8,"power":0.75,"accuracy":4,"cooldown":3,"stun":1,"description":"Puede aturdir al rival durante un turno."},
    "disarm": {"name":"Desarmar","energy":18,"weight":6,"power":0.55,"accuracy":-8,"cooldown":4,"weaken":3,"description":"Reduce temporalmente el ataque enemigo."},
    "sunder": {"name":"Romper armadura","energy":18,"weight":7,"power":0.90,"accuracy":-4,"cooldown":4,"armor_break":4,"description":"Reduce la defensa del rival."},
    "warcry": {"name":"Grito de guerra","energy":8,"weight":6,"power":0.0,"accuracy":0,"cooldown":4,"attack_buff":4,"description":"Aumenta el ataque propio durante el combate."},
    "throw_sand": {"name":"Arrojar arena","energy":10,"weight":5,"power":0.35,"accuracy":12,"cooldown":4,"blind":12,"description":"Reduce la precisión del enemigo."},
    "execute": {"name":"Ejecución","energy":24,"weight":3,"power":1.85,"accuracy":-12,"cooldown":5,"finisher":true,"description":"Solo se prioriza contra rivales muy heridos."}
}

var last_result: Dictionary = {}
var last_combat_day: int = -1
var next_battle_config: Dictionary = {
    "target_rule":"weakest",
    "energy_rule":"balanced",
    "surrender_threshold":20,
    "allow_finisher":true,
    "techniques":["basic_attack","guard","feint","lunge","shield_bash"]
}

func get_tactic_ids() -> Array[String]:
    var result: Array[String] = []
    for tactic_id in TACTICS.keys():
        result.append(str(tactic_id))
    return result

func get_tactic_name(tactic_id: String) -> String:
    return str(TACTICS.get(tactic_id, tactic_id.capitalize()))

func get_technique_ids() -> Array[String]:
    var result: Array[String] = []
    for technique_id in TECHNIQUES.keys():
        result.append(str(technique_id))
    return result

func get_technique(technique_id: String) -> Dictionary:
    return TECHNIQUES.get(technique_id, {}).duplicate(true)

func configure_next_battle(config: Dictionary) -> void:
    var cleaned: Dictionary = next_battle_config.duplicate(true)
    cleaned["target_rule"] = str(config.get("target_rule", cleaned.get("target_rule", "weakest")))
    cleaned["energy_rule"] = str(config.get("energy_rule", cleaned.get("energy_rule", "balanced")))
    cleaned["surrender_threshold"] = clampi(int(config.get("surrender_threshold", cleaned.get("surrender_threshold", 20))), 0, 60)
    cleaned["allow_finisher"] = bool(config.get("allow_finisher", cleaned.get("allow_finisher", true)))
    var selected: Array[String] = []
    for value in config.get("techniques", cleaned.get("techniques", [])):
        var technique_id: String = str(value)
        if TECHNIQUES.has(technique_id) and not selected.has(technique_id):
            selected.append(technique_id)
    if not selected.has("basic_attack"):
        selected.push_front("basic_attack")
    cleaned["techniques"] = selected.slice(0, 5)
    next_battle_config = cleaned

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

func get_current_event_details() -> Dictionary:
    var event_type: String = get_current_event_type()
    if event_type == "official":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Duelo reglamentado. Otorga reputación y cumple contratos.","risk":"Heridas moderadas","reward":"Denarios + reputación","team_size":1}
    if event_type == "underground":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Sin árbitros. Mayor pago, sin prestigio oficial.","risk":"Heridas graves más probables","reward":"Denarios aumentados","team_size":1}
    return {"type":"none","name":get_current_event_name(),"rules":get_next_event_summary(),"risk":"Sin combate","reward":"—","team_size":0}

func get_next_event_summary() -> String:
    if get_current_event_type() != "none":
        return get_current_event_name()
    var next_underground: int = GameState.day + (3 - GameState.day % 3)
    var next_official: int = GameState.day + (7 - GameState.day % 7)
    return "Próximo clandestino: día %d. Próximo oficial: día %d." % [next_underground, next_official]

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
    var player: Dictionary = _build_combatant(fighter, tactic, next_battle_config.get("techniques", []))
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var actions: Array[Dictionary] = []
    var combat_log: Array[String] = []
    var round: int = 0
    var surrendered: bool = false
    var relationship_bonus: int = RelationshipManager.get_combat_morale_bonus(fighter.id)

    combat_log.append("[b]%s — Día %d[/b]" % [get_current_event_name(), GameState.day])
    combat_log.append("%s entra con táctica %s." % [fighter.display_name, get_tactic_name(tactic)])
    combat_log.append("Órdenes: energía %s, rendición bajo %d%%." % [str(next_battle_config.get("energy_rule", "balanced")), int(next_battle_config.get("surrender_threshold", 20))])
    actions.append(_snapshot_action("intro", 0, "%s contra %s" % [fighter.display_name, enemy.name], player, enemy, ""))

    while player.health > 0 and enemy.health > 0 and round < 30:
        round += 1
        _tick_status(player)
        _tick_status(enemy)
        combat_log.append("--- Ronda %d ---" % round)
        actions.append(_snapshot_action("round", round, "Comienza la ronda %d" % round, player, enemy, ""))
        if int(player.get("stunned", 0)) > 0:
            combat_log.append("%s está aturdido y pierde el turno." % player.name)
            actions.append(_snapshot_action("status", round, "%s pierde el turno por aturdimiento" % player.name, player, enemy, "stun"))
        else:
            _perform_technique(player, enemy, rng, combat_log, actions, round, true)
        if enemy.health <= 0:
            break
        if int(enemy.get("stunned", 0)) > 0:
            combat_log.append("%s está aturdido y pierde el turno." % enemy.name)
            actions.append(_snapshot_action("status", round, "%s pierde el turno por aturdimiento" % enemy.name, player, enemy, "stun"))
        else:
            _perform_technique(enemy, player, rng, combat_log, actions, round, false)
        if _should_surrender(fighter, player, tactic, rng):
            surrendered = true
            combat_log.append("%s arroja el arma y se rinde." % fighter.display_name)
            actions.append(_snapshot_action("surrender", round, "%s se rinde" % fighter.display_name, player, enemy, "surrender"))
            break
        player.energy = mini(player.max_energy, player.energy + 6)
        enemy.energy = mini(enemy.max_energy, enemy.energy + 6)

    var victory: bool = enemy.health <= 0 and player.health > 0 and not surrendered
    var reward: int = 0
    var reputation: int = 0
    var injury: String = _resolve_injury(fighter, player, victory, surrendered, rng, event_type)
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
        if event_type == "official": GameState.reputation = maxi(0, GameState.reputation - 1)
    else:
        fighter.morale = maxi(0, fighter.morale - 10 + relationship_bonus)

    var personality_event: Dictionary = PersonalityManager.register_combat_result(fighter, victory, surrendered, fighter.injury_severity)
    EconomyManager.register_combat_result(victory)
    var tournament_result: Dictionary = {}
    if event_type == "official":
        tournament_result = TournamentManager.register_combat_result(fighter.id, victory)

    last_combat_day = GameState.day
    var technique_stats: Dictionary = _summarize_techniques(actions, fighter.display_name)
    actions.append(_snapshot_action("result", round, "VICTORIA" if victory else ("RENDICIÓN" if surrendered else "DERROTA"), player, enemy, "victory" if victory else "defeat"))
    last_result = {
        "event_type":event_type,"event_name":get_current_event_name(),"event_details":get_current_event_details(),
        "victory":victory,"surrendered":surrendered,"rounds":round,"fighter":fighter.display_name,"fighter_id":fighter.id,
        "enemy":enemy.name,"tactic":tactic,"instructions":next_battle_config.duplicate(true),
        "player_health":maxi(0, player.health),"player_max_health":player.max_health,"player_energy":maxi(0, player.energy),"player_max_energy":player.max_energy,
        "enemy_health":maxi(0, enemy.health),"enemy_max_health":enemy.max_health,"enemy_energy":maxi(0, enemy.energy),"enemy_max_energy":enemy.max_energy,
        "player_attack":player.attack,"player_defense":player.defense,"enemy_attack":enemy.attack,"enemy_defense":enemy.defense,
        "reward":reward,"reputation":reputation,"injury":injury,"injury_days":fighter.injury_days,"tournament":tournament_result,
        "personality":personality_event,"relationship_bonus":relationship_bonus,"actions":actions,"technique_stats":technique_stats,"log":combat_log
    }
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    for action in actions:
        combat_turn.emit(action)
    combat_finished.emit(last_result)
    return last_result

func _perform_technique(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator, combat_log: Array[String], actions: Array[Dictionary], round: int, player_is_attacker: bool) -> void:
    var technique_id: String = _choose_technique(attacker, defender, rng)
    var technique: Dictionary = TECHNIQUES.get(technique_id, TECHNIQUES["basic_attack"])
    var cost: int = int(technique.get("energy", 10))
    if attacker.energy < cost:
        attacker.energy = mini(attacker.max_energy, attacker.energy + 14)
        var rest_text: String = "%s recupera energía." % attacker.name
        combat_log.append(rest_text)
        actions.append(_action_with_orientation("recover", round, rest_text, attacker, defender, "recover", player_is_attacker))
        return
    attacker.energy -= cost
    attacker.cooldowns[technique_id] = int(technique.get("cooldown", 0))
    if technique_id == "guard":
        attacker.guarding = 1
        var guard_text: String = "%s adopta una guardia cerrada." % attacker.name
        combat_log.append(guard_text)
        actions.append(_action_with_orientation("guard", round, guard_text, attacker, defender, technique_id, player_is_attacker))
        return
    if technique_id == "warcry":
        attacker.attack_buff = int(attacker.get("attack_buff", 0)) + int(technique.get("attack_buff", 4))
        var cry_text: String = "%s lanza un grito de guerra y aumenta su ataque." % attacker.name
        combat_log.append(cry_text)
        actions.append(_action_with_orientation("buff", round, cry_text, attacker, defender, technique_id, player_is_attacker))
        return
    var hit_chance: int = clampi(int(attacker.accuracy) + int(technique.get("accuracy", 0)) - int(defender.get("blind", 0)), 18, 96)
    if rng.randi_range(1, 100) > hit_chance:
        var miss_text: String = "%s usa %s, pero falla." % [attacker.name, technique.get("name", technique_id)]
        combat_log.append(miss_text)
        actions.append(_action_with_orientation("miss", round, miss_text, attacker, defender, technique_id, player_is_attacker))
        return
    var raw_damage: int = int(round((int(attacker.attack) + int(attacker.get("attack_buff", 0))) * float(technique.get("power", 1.0))))
    var effective_defense: int = maxi(0, int(defender.defense) - int(defender.get("armor_break", 0)))
    var damage: int = maxi(1, raw_damage + rng.randi_range(-3, 4) - floori(float(effective_defense) / 2.0))
    if int(defender.get("guarding", 0)) > 0:
        damage = maxi(1, floori(float(damage) * 0.45))
        defender.guarding = 0
    defender.health -= damage
    if int(technique.get("stun", 0)) > 0: defender.stunned = maxi(int(defender.get("stunned", 0)), int(technique.get("stun", 0)))
    if int(technique.get("weaken", 0)) > 0: defender.attack_buff = int(defender.get("attack_buff", 0)) - int(technique.get("weaken", 0))
    if int(technique.get("armor_break", 0)) > 0: defender.armor_break = int(defender.get("armor_break", 0)) + int(technique.get("armor_break", 0))
    if int(technique.get("blind", 0)) > 0: defender.blind = maxi(int(defender.get("blind", 0)), int(technique.get("blind", 0)))
    var hit_text: String = "%s usa %s y causa %d de daño a %s." % [attacker.name, technique.get("name", technique_id), damage, defender.name]
    combat_log.append(hit_text)
    var action: Dictionary = _action_with_orientation("hit", round, hit_text, attacker, defender, technique_id, player_is_attacker)
    action["damage"] = damage
    actions.append(action)

func _choose_technique(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator) -> String:
    var candidates: Array[String] = []
    for technique_value in attacker.get("techniques", ["basic_attack"]):
        var technique_id: String = str(technique_value)
        if not TECHNIQUES.has(technique_id): continue
        if int(attacker.cooldowns.get(technique_id, 0)) > 0: continue
        var data: Dictionary = TECHNIQUES[technique_id]
        if attacker.energy < int(data.get("energy", 0)): continue
        if bool(data.get("finisher", false)):
            var enemy_ratio: float = float(maxi(0, defender.health)) / float(maxi(1, defender.max_health))
            if enemy_ratio > 0.30 or not bool(next_battle_config.get("allow_finisher", true)): continue
        var repeats: int = maxi(1, int(data.get("weight", 5)) / 3)
        for _index in range(repeats): candidates.append(technique_id)
    if candidates.is_empty(): return "basic_attack"
    return candidates[rng.randi_range(0, candidates.size() - 1)]

func _tick_status(combatant: Dictionary) -> void:
    for key in combatant.cooldowns.keys(): combatant.cooldowns[key] = maxi(0, int(combatant.cooldowns[key]) - 1)
    combatant.stunned = maxi(0, int(combatant.get("stunned", 0)) - 1)
    combatant.blind = maxi(0, int(combatant.get("blind", 0)) - 3)

func _should_surrender(fighter, player: Dictionary, tactic: String, rng: RandomNumberGenerator) -> bool:
    if player.health <= 0: return false
    var health_percent: int = floori(100.0 * float(player.health) / float(maxi(1, player.max_health)))
    var threshold: int = int(next_battle_config.get("surrender_threshold", 20))
    if health_percent > threshold: return false
    var personality: Dictionary = PersonalityManager.get_combat_modifiers(fighter.id, fighter.traits)
    var chance: int = 35 + maxi(0, 45 - fighter.morale) + int(personality.get("surrender", 0))
    if tactic == "aggressive": chance -= 14
    if tactic == "careful": chance += 8
    return rng.randi_range(1, 100) <= clampi(chance, 8, 88)

func _resolve_injury(fighter, player: Dictionary, victory: bool, surrendered: bool, rng: RandomNumberGenerator, event_type: String) -> String:
    var health_ratio: float = float(maxi(0, player.health)) / float(maxi(1, player.max_health))
    var chance: int = 10 + (10 if event_type == "underground" else 0)
    if health_ratio <= 0.0: chance = 80
    elif health_ratio < 0.25: chance += 42
    elif health_ratio < 0.50: chance += 18
    if surrendered: chance -= 15
    if victory: chance -= 4
    chance -= EstateManager.get_level("infirmary") * 2
    if rng.randi_range(1, 100) > clampi(chance, 2, 92): return ""
    var severity: int = 1
    if health_ratio <= 0.0 or rng.randi_range(1, 100) <= 18: severity = 3
    elif health_ratio < 0.25 or rng.randi_range(1, 100) <= 42: severity = 2
    var pools: Dictionary = {1:["Contusión","Corte superficial","Esguince"],2:["Herida profunda","Costilla fisurada","Luxación"],3:["Fractura grave","Trauma severo","Herida crítica"]}
    var pool: Array = pools[severity]
    var injury_name: String = str(pool[rng.randi_range(0, pool.size() - 1)])
    var days: int = severity * 2 + rng.randi_range(0, severity * 2)
    fighter.apply_injury(injury_name, severity, days)
    return "%s; recuperación: %d día(s)" % [injury_name, days]

func _build_combatant(person, tactic: String, techniques: Array) -> Dictionary:
    var equipment: Dictionary = EquipmentManager.get_equipped_stats(person)
    var progression: Dictionary = GladiatorProgressionManager.get_modifiers(person.id)
    var personality: Dictionary = PersonalityManager.get_combat_modifiers(person.id, person.traits)
    var relationship_bonus: int = RelationshipManager.get_combat_morale_bonus(person.id)
    var attack: int = int(round((person.get_base_attack() + int(equipment.get("power", 0)) + int(progression.get("attack_bonus", 0))) * float(progression.get("attack", 1.0)) * float(personality.get("attack", 1.0))))
    var defense: int = int(round((person.get_base_defense() + int(equipment.get("defense", 0)) + int(progression.get("defense_bonus", 0))) * float(progression.get("defense", 1.0))))
    var max_health: int = int(round(person.get_max_health() * float(progression.get("health", 1.0))))
    var max_energy: int = int(round((person.get_max_energy() + int(progression.get("energy_bonus", 0)) + maxi(0, relationship_bonus)) * float(progression.get("energy", 1.0))))
    var accuracy: int = 55 + person.agility * 3 + int(progression.get("accuracy_bonus", 0)) + int(personality.get("accuracy", 0))
    if tactic == "aggressive": attack = int(attack * 1.18); defense = int(defense * 0.86)
    elif tactic == "defensive": defense = int(defense * 1.24); attack = int(attack * 0.90)
    elif tactic == "careful": accuracy += 12; attack = int(attack * 0.94)
    return {"name":person.display_name,"health":max_health,"max_health":max_health,"energy":max_energy,"max_energy":max_energy,"attack":attack,"defense":defense,"accuracy":accuracy,"techniques":techniques.duplicate(),"cooldowns":{},"guarding":0,"stunned":0,"blind":0,"armor_break":0,"attack_buff":0,"reward_multiplier":float(progression.get("reward_multiplier", 1.0))}

func _generate_enemy(person, event_type: String) -> Dictionary:
    var tier: int = maxi(1, floori(float(person.strength + person.agility + person.endurance) / 8.0)) + (1 if event_type == "official" else 0)
    var enemy_techniques: Array[String] = ["basic_attack","guard","feint","lunge"]
    if tier >= 3: enemy_techniques.append("shield_bash")
    if tier >= 4: enemy_techniques.append("sunder")
    return {"name":("Campeón oficial" if event_type == "official" else "Luchador clandestino") + " nivel %d" % tier,"health":78+tier*20,"max_health":78+tier*20,"energy":72+tier*9,"max_energy":72+tier*9,"attack":15+tier*5,"defense":8+tier*4,"accuracy":58+tier*3,"techniques":enemy_techniques,"cooldowns":{},"guarding":0,"stunned":0,"blind":0,"armor_break":0,"attack_buff":0}

func _snapshot_action(type_id: String, round: int, text: String, player: Dictionary, enemy: Dictionary, technique: String) -> Dictionary:
    return {"type":type_id,"round":round,"text":text,"technique":technique,"actor":"system","player_health":maxi(0,int(player.health)),"player_max_health":int(player.max_health),"player_energy":maxi(0,int(player.energy)),"player_max_energy":int(player.max_energy),"enemy_health":maxi(0,int(enemy.health)),"enemy_max_health":int(enemy.max_health),"enemy_energy":maxi(0,int(enemy.energy)),"enemy_max_energy":int(enemy.max_energy)}

func _action_with_orientation(type_id: String, round: int, text: String, attacker: Dictionary, defender: Dictionary, technique: String, player_is_attacker: bool) -> Dictionary:
    var player: Dictionary = attacker if player_is_attacker else defender
    var enemy: Dictionary = defender if player_is_attacker else attacker
    var action: Dictionary = _snapshot_action(type_id, round, text, player, enemy, technique)
    action["actor"] = "player" if player_is_attacker else "enemy"
    return action

func _summarize_techniques(actions: Array[Dictionary], fighter_name: String) -> Dictionary:
    var stats: Dictionary = {}
    for action in actions:
        if str(action.get("actor", "")) != "player": continue
        var technique_id: String = str(action.get("technique", ""))
        if technique_id.is_empty(): continue
        if not stats.has(technique_id): stats[technique_id] = {"name":get_technique(technique_id).get("name", technique_id),"uses":0,"damage":0}
        stats[technique_id]["uses"] = int(stats[technique_id].get("uses", 0)) + 1
        stats[technique_id]["damage"] = int(stats[technique_id].get("damage", 0)) + int(action.get("damage", 0))
    return stats
