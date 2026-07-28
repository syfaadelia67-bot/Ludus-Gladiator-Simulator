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
    "lunge": {"name":"Estocada","energy":16,"weight":11,"power":1.35,"accuracy":-5,"cooldown":2,"bleed":2,"description":"Ataque potente que puede provocar sangrado."},
    "shield_bash": {"name":"Golpe con escudo","energy":14,"weight":8,"power":0.75,"accuracy":4,"cooldown":3,"stun":1,"knockdown":1,"description":"Puede aturdir y derribar al rival."},
    "disarm": {"name":"Desarmar","energy":18,"weight":6,"power":0.55,"accuracy":-8,"cooldown":4,"weaken":4,"description":"Reduce temporalmente el ataque enemigo."},
    "sunder": {"name":"Romper armadura","energy":18,"weight":7,"power":0.90,"accuracy":-4,"cooldown":4,"armor_break":5,"description":"Reduce la defensa del rival."},
    "warcry": {"name":"Grito de guerra","energy":8,"weight":6,"power":0.0,"accuracy":0,"cooldown":4,"attack_buff":4,"description":"Aumenta el ataque propio durante el combate."},
    "throw_sand": {"name":"Arrojar arena","energy":10,"weight":5,"power":0.35,"accuracy":12,"cooldown":4,"blind":15,"description":"Reduce la precisión del enemigo."},
    "execute": {"name":"Ejecución","energy":24,"weight":3,"power":1.85,"accuracy":-12,"cooldown":5,"finisher":true,"description":"Remate contra rivales muy heridos."}
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
        var technique_id := str(value)
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
    var event_type := get_current_event_type()
    if event_type == "official":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Duelo reglamentado. Otorga reputación y cumple contratos.","risk":"Heridas moderadas","reward":"Denarios + reputación","team_size":1}
    if event_type == "underground":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Sin árbitros. Mayor pago, sin prestigio oficial.","risk":"Heridas graves más probables","reward":"Denarios aumentados","team_size":1}
    return {"type":"none","name":get_current_event_name(),"rules":get_next_event_summary(),"risk":"Sin combate","reward":"—","team_size":0}

func get_next_event_summary() -> String:
    if get_current_event_type() != "none":
        return get_current_event_name()
    var next_underground := GameState.day + (3 - GameState.day % 3)
    var next_official := GameState.day + (7 - GameState.day % 7)
    return "Próximo clandestino: día %d. Próximo oficial: día %d." % [next_underground, next_official]

func simulate_duel(gladiator_id: String, tactic: String = "balanced") -> Dictionary:
    var event_type := get_current_event_type()
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

    var valid_techniques: Array = next_battle_config.get("techniques", [])
    if EquipmentManager.has_method("get_available_combat_techniques"):
        valid_techniques = EquipmentManager.get_available_combat_techniques(fighter)
        var requested: Array = next_battle_config.get("techniques", [])
        valid_techniques = valid_techniques.filter(func(id): return requested.has(id))
        if not valid_techniques.has("basic_attack"):
            valid_techniques.push_front("basic_attack")

    var enemy := _generate_enemy(fighter, event_type)
    var player := _build_combatant(fighter, tactic, valid_techniques)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var actions: Array[Dictionary] = []
    var combat_log: Array[String] = []
    var round := 0
    var surrendered := false
    var relationship_bonus := RelationshipManager.get_combat_morale_bonus(fighter.id)

    combat_log.append("[b]%s — Día %d[/b]" % [get_current_event_name(), GameState.day])
    combat_log.append("%s entra con táctica %s." % [fighter.display_name, get_tactic_name(tactic)])
    actions.append(_snapshot_action("intro", 0, "%s contra %s" % [fighter.display_name, enemy.name], player, enemy, ""))

    while player.health > 0 and enemy.health > 0 and round < 30:
        round += 1
        _apply_round_status(player, enemy, actions, combat_log, round, true)
        _apply_round_status(enemy, player, actions, combat_log, round, false)
        _tick_cooldowns(player)
        _tick_cooldowns(enemy)
        if player.health <= 0 or enemy.health <= 0:
            break
        actions.append(_snapshot_action("round", round, "Comienza la ronda %d" % round, player, enemy, ""))

        if int(player.get("stunned", 0)) > 0 or int(player.get("knocked_down", 0)) > 0:
            var status_text := "%s pierde el turno por %s." % [player.name, "derribo" if int(player.get("knocked_down", 0)) > 0 else "aturdimiento"]
            actions.append(_snapshot_action("status", round, status_text, player, enemy, "status"))
        else:
            _perform_technique(player, enemy, rng, combat_log, actions, round, true)
        if enemy.health <= 0:
            break

        if int(enemy.get("stunned", 0)) > 0 or int(enemy.get("knocked_down", 0)) > 0:
            var enemy_status_text := "%s pierde el turno por %s." % [enemy.name, "derribo" if int(enemy.get("knocked_down", 0)) > 0 else "aturdimiento"]
            actions.append(_snapshot_action("status", round, enemy_status_text, player, enemy, "status"))
        else:
            _perform_technique(enemy, player, rng, combat_log, actions, round, false)

        if _should_surrender(fighter, player, tactic, rng):
            surrendered = true
            actions.append(_snapshot_action("surrender", round, "%s se rinde" % fighter.display_name, player, enemy, "surrender"))
            break
        player.energy = mini(player.max_energy, player.energy + _energy_regeneration())
        enemy.energy = mini(enemy.max_energy, enemy.energy + 6)

    var victory := enemy.health <= 0 and player.health > 0 and not surrendered
    var reward := 0
    var reputation := 0
    var injury := _resolve_injury(fighter, player, victory, surrendered, rng, event_type)
    fighter.fatigue = mini(100, fighter.fatigue + 8 + floori(float(round) / 2.0))

    if victory:
        var base_reward := 70 + int(enemy.attack) * 3
        var multiplier := 1.35 if event_type == "underground" else 1.0
        reward = int(round(base_reward * multiplier * float(player.get("reward_multiplier", 1.0))))
        reputation = 0 if event_type == "underground" else 2 + floori(float(int(enemy.defense)) / 8.0)
        GameState.denarii += reward
        GameState.reputation += reputation
        fighter.morale = mini(100, fighter.morale + 8 + maxi(0, relationship_bonus))
    elif surrendered:
        fighter.morale = maxi(0, fighter.morale - 6 + relationship_bonus)
        if event_type == "official":
            GameState.reputation = maxi(0, GameState.reputation - 1)
    else:
        fighter.morale = maxi(0, fighter.morale - 10 + relationship_bonus)

    var personality_event := PersonalityManager.register_combat_result(fighter, victory, surrendered, fighter.injury_severity)
    EconomyManager.register_combat_result(victory)
    var tournament_result: Dictionary = {}
    if event_type == "official":
        tournament_result = TournamentManager.register_combat_result(fighter.id, victory)

    last_combat_day = GameState.day
    var technique_stats := _summarize_techniques(actions)
    var status_stats := _summarize_statuses(actions)
    actions.append(_snapshot_action("result", round, "VICTORIA" if victory else ("RENDICIÓN" if surrendered else "DERROTA"), player, enemy, "victory" if victory else "defeat"))
    last_result = {
        "event_type":event_type,"event_name":get_current_event_name(),"event_details":get_current_event_details(),
        "victory":victory,"surrendered":surrendered,"rounds":round,"fighter":fighter.display_name,"fighter_id":fighter.id,
        "enemy":enemy.name,"tactic":tactic,"instructions":next_battle_config.duplicate(true),
        "player_health":maxi(0, player.health),"player_max_health":player.max_health,"player_energy":maxi(0, player.energy),"player_max_energy":player.max_energy,
        "enemy_health":maxi(0, enemy.health),"enemy_max_health":enemy.max_health,"enemy_energy":maxi(0, enemy.energy),"enemy_max_energy":enemy.max_energy,
        "player_attack":player.attack,"player_defense":player.defense,"enemy_attack":enemy.attack,"enemy_defense":enemy.defense,
        "reward":reward,"reputation":reputation,"injury":injury,"injury_days":fighter.injury_days,"tournament":tournament_result,
        "personality":personality_event,"relationship_bonus":relationship_bonus,"actions":actions,"technique_stats":technique_stats,"status_stats":status_stats,"log":combat_log
    }
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    for action in actions:
        combat_turn.emit(action)
    combat_finished.emit(last_result)
    return last_result

func _perform_technique(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator, combat_log: Array[String], actions: Array[Dictionary], round: int, player_is_attacker: bool) -> void:
    var technique_id := _choose_technique(attacker, defender, rng)
    var technique: Dictionary = TECHNIQUES.get(technique_id, TECHNIQUES["basic_attack"])
    var cost := int(technique.get("energy", 10))
    if attacker.energy < cost:
        attacker.energy = mini(attacker.max_energy, attacker.energy + 14)
        actions.append(_action_with_orientation("recover", round, "%s recupera energía." % attacker.name, attacker, defender, "recover", player_is_attacker))
        return
    attacker.energy -= cost
    attacker.cooldowns[technique_id] = int(technique.get("cooldown", 0))
    if technique_id == "guard":
        attacker.guarding = 1
        actions.append(_action_with_orientation("guard", round, "%s adopta una guardia cerrada." % attacker.name, attacker, defender, technique_id, player_is_attacker))
        return
    if technique_id == "warcry":
        attacker.attack_buff = int(attacker.get("attack_buff", 0)) + int(technique.get("attack_buff", 4))
        actions.append(_action_with_orientation("buff", round, "%s lanza un grito de guerra." % attacker.name, attacker, defender, technique_id, player_is_attacker))
        return

    var hit_chance := clampi(int(attacker.accuracy) + int(technique.get("accuracy", 0)) - int(attacker.get("blind", 0)), 18, 96)
    if rng.randi_range(1, 100) > hit_chance:
        actions.append(_action_with_orientation("miss", round, "%s usa %s, pero falla." % [attacker.name, technique.get("name", technique_id)], attacker, defender, technique_id, player_is_attacker))
        return

    var raw_damage := int(round((int(attacker.attack) + int(attacker.get("attack_buff", 0))) * float(technique.get("power", 1.0))))
    var effective_defense := maxi(0, int(defender.defense) - int(defender.get("armor_break", 0)))
    var damage := maxi(1, raw_damage + rng.randi_range(-3, 4) - floori(float(effective_defense) / 2.0))
    if int(defender.get("guarding", 0)) > 0:
        damage = maxi(1, floori(float(damage) * 0.45))
        defender.guarding = 0
    defender.health -= damage
    if int(technique.get("stun", 0)) > 0: defender.stunned = maxi(int(defender.get("stunned", 0)), int(technique.get("stun", 0)))
    if int(technique.get("knockdown", 0)) > 0: defender.knocked_down = maxi(int(defender.get("knocked_down", 0)), int(technique.get("knockdown", 0)))
    if int(technique.get("bleed", 0)) > 0: defender.bleeding = maxi(int(defender.get("bleeding", 0)), int(technique.get("bleed", 0)))
    if int(technique.get("weaken", 0)) > 0: defender.attack_buff = int(defender.get("attack_buff", 0)) - int(technique.get("weaken", 0))
    if int(technique.get("armor_break", 0)) > 0: defender.armor_break = int(defender.get("armor_break", 0)) + int(technique.get("armor_break", 0))
    if int(technique.get("blind", 0)) > 0: defender.blind = maxi(int(defender.get("blind", 0)), int(technique.get("blind", 0)))
    var action := _action_with_orientation("hit", round, "%s usa %s y causa %d de daño a %s." % [attacker.name, technique.get("name", technique_id), damage, defender.name], attacker, defender, technique_id, player_is_attacker)
    action["damage"] = damage
    action["applied_status"] = _status_from_technique(technique)
    actions.append(action)

func _choose_technique(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator) -> String:
    var available: Array[String] = []
    for value in attacker.get("techniques", ["basic_attack"]):
        var id := str(value)
        if not TECHNIQUES.has(id): continue
        if int(attacker.cooldowns.get(id, 0)) > 0: continue
        var data: Dictionary = TECHNIQUES[id]
        if attacker.energy < int(data.get("energy", 0)): continue
        if bool(data.get("finisher", false)):
            var target_ratio := float(maxi(0, defender.health)) / float(maxi(1, defender.max_health))
            if target_ratio > 0.30 or not bool(next_battle_config.get("allow_finisher", true)): continue
        available.append(id)
    if available.is_empty():
        return "basic_attack"

    var self_ratio := float(attacker.health) / float(maxi(1, attacker.max_health))
    var enemy_ratio := float(defender.health) / float(maxi(1, defender.max_health))
    if available.has("execute") and enemy_ratio <= 0.25:
        return "execute"
    if available.has("guard") and self_ratio <= 0.35 and int(attacker.get("guarding", 0)) == 0:
        return "guard"
    if available.has("warcry") and int(attacker.get("attack_buff", 0)) <= 0 and self_ratio > 0.55:
        return "warcry"
    if available.has("sunder") and int(defender.get("armor_break", 0)) < 5 and int(defender.defense) >= int(attacker.attack) / 2:
        return "sunder"
    if available.has("throw_sand") and int(defender.get("blind", 0)) <= 0 and int(defender.accuracy) >= 70:
        return "throw_sand"
    if available.has("shield_bash") and int(defender.get("stunned", 0)) <= 0 and rng.randf() < 0.45:
        return "shield_bash"
    if available.has("lunge") and enemy_ratio <= 0.55 and attacker.energy >= 24:
        return "lunge"

    var weighted: Array[String] = []
    for id in available:
        var repeats := maxi(1, int(TECHNIQUES[id].get("weight", 5)) / 4)
        for _i in range(repeats):
            weighted.append(id)
    return weighted[rng.randi_range(0, weighted.size() - 1)]

func _apply_round_status(combatant: Dictionary, opponent: Dictionary, actions: Array[Dictionary], combat_log: Array[String], round: int, player_is_combatant: bool) -> void:
    if int(combatant.get("bleeding", 0)) > 0:
        var bleed_damage := maxi(1, int(combatant.max_health) / 30)
        combatant.health -= bleed_damage
        combatant.bleeding = maxi(0, int(combatant.bleeding) - 1)
        var text := "%s pierde %d de vida por sangrado." % [combatant.name, bleed_damage]
        combat_log.append(text)
        var action := _action_with_orientation("status_damage", round, text, combatant, opponent, "bleeding", player_is_combatant)
        action["damage"] = bleed_damage
        action["applied_status"] = "sangrado"
        actions.append(action)
    combatant.stunned = maxi(0, int(combatant.get("stunned", 0)) - 1)
    combatant.knocked_down = maxi(0, int(combatant.get("knocked_down", 0)) - 1)
    combatant.blind = maxi(0, int(combatant.get("blind", 0)) - 3)

func _tick_cooldowns(combatant: Dictionary) -> void:
    for key in combatant.cooldowns.keys():
        combatant.cooldowns[key] = maxi(0, int(combatant.cooldowns[key]) - 1)

func _energy_regeneration() -> int:
    match str(next_battle_config.get("energy_rule", "balanced")):
        "conserve": return 9
        "spend": return 4
        _: return 6

func _should_surrender(fighter, player: Dictionary, tactic: String, rng: RandomNumberGenerator) -> bool:
    if player.health <= 0: return false
    var health_percent := floori(100.0 * float(player.health) / float(maxi(1, player.max_health)))
    var threshold := int(next_battle_config.get("surrender_threshold", 20))
    if threshold <= 0 or health_percent > threshold: return false
    var personality := PersonalityManager.get_combat_modifiers(fighter.id, fighter.traits)
    var chance := 35 + maxi(0, 45 - fighter.morale) + int(personality.get("surrender", 0))
    if tactic == "aggressive": chance -= 14
    if tactic == "careful": chance += 8
    return rng.randi_range(1, 100) <= clampi(chance, 8, 88)

func _resolve_injury(fighter, player: Dictionary, victory: bool, surrendered: bool, rng: RandomNumberGenerator, event_type: String) -> String:
    var health_ratio := float(maxi(0, player.health)) / float(maxi(1, player.max_health))
    var chance := 10 + (10 if event_type == "underground" else 0)
    if health_ratio <= 0.0: chance = 80
    elif health_ratio < 0.25: chance += 42
    elif health_ratio < 0.50: chance += 18
    if surrendered: chance -= 15
    if victory: chance -= 4
    chance -= EstateManager.get_level("infirmary") * 2
    if rng.randi_range(1, 100) > clampi(chance, 2, 92): return ""
    var severity := 1
    if health_ratio <= 0.0 or rng.randi_range(1, 100) <= 18: severity = 3
    elif health_ratio < 0.25 or rng.randi_range(1, 100) <= 42: severity = 2
    var pools := {1:["Contusión","Corte superficial","Esguince"],2:["Herida profunda","Costilla fisurada","Luxación"],3:["Fractura grave","Trauma severo","Herida crítica"]}
    var pool: Array = pools[severity]
    var injury_name := str(pool[rng.randi_range(0, pool.size() - 1)])
    var days := severity * 2 + rng.randi_range(0, severity * 2)
    fighter.apply_injury(injury_name, severity, days)
    return "%s; recuperación: %d día(s)" % [injury_name, days]

func _build_combatant(person, tactic: String, techniques: Array) -> Dictionary:
    var equipment := EquipmentManager.get_equipped_stats(person)
    var progression := GladiatorProgressionManager.get_modifiers(person.id)
    var personality := PersonalityManager.get_combat_modifiers(person.id, person.traits)
    var relationship_bonus := RelationshipManager.get_combat_morale_bonus(person.id)
    var attack := int(round((person.get_base_attack() + int(equipment.get("power", 0)) + int(progression.get("attack_bonus", 0))) * float(progression.get("attack", 1.0)) * float(personality.get("attack", 1.0))))
    var defense := int(round((person.get_base_defense() + int(equipment.get("defense", 0)) + int(progression.get("defense_bonus", 0))) * float(progression.get("defense", 1.0))))
    var max_health := int(round(person.get_max_health() * float(progression.get("health", 1.0))))
    var max_energy := int(round((person.get_max_energy() + int(progression.get("energy_bonus", 0)) + maxi(0, relationship_bonus)) * float(progression.get("energy", 1.0))))
    var accuracy := 55 + person.agility * 3 + int(progression.get("accuracy_bonus", 0)) + int(personality.get("accuracy", 0))
    if tactic == "aggressive": attack = int(attack * 1.18); defense = int(defense * 0.86)
    elif tactic == "defensive": defense = int(defense * 1.24); attack = int(attack * 0.90)
    elif tactic == "careful": accuracy += 12; attack = int(attack * 0.94)
    return {"name":person.display_name,"health":max_health,"max_health":max_health,"energy":max_energy,"max_energy":max_energy,"attack":attack,"defense":defense,"accuracy":accuracy,"techniques":techniques.duplicate(),"cooldowns":{},"guarding":0,"stunned":0,"knocked_down":0,"bleeding":0,"blind":0,"armor_break":0,"attack_buff":0,"reward_multiplier":float(progression.get("reward_multiplier", 1.0))}

func _generate_enemy(person, event_type: String) -> Dictionary:
    var tier := maxi(1, floori(float(person.strength + person.agility + person.endurance) / 8.0)) + (1 if event_type == "official" else 0)
    var techniques: Array[String] = ["basic_attack","guard","feint","lunge"]
    if tier >= 3: techniques.append("shield_bash")
    if tier >= 4: techniques.append("sunder")
    return {"name":("Campeón oficial" if event_type == "official" else "Luchador clandestino") + " nivel %d" % tier,"health":78+tier*20,"max_health":78+tier*20,"energy":72+tier*9,"max_energy":72+tier*9,"attack":15+tier*5,"defense":8+tier*4,"accuracy":58+tier*3,"techniques":techniques,"cooldowns":{},"guarding":0,"stunned":0,"knocked_down":0,"bleeding":0,"blind":0,"armor_break":0,"attack_buff":0}

func _snapshot_action(type_id: String, round_value: int, text: String, player: Dictionary, enemy: Dictionary, technique: String) -> Dictionary:
    return {"type":type_id,"round":round_value,"text":text,"technique":technique,"actor":"system","player_health":maxi(0,int(player.health)),"player_max_health":int(player.max_health),"player_energy":maxi(0,int(player.energy)),"player_max_energy":int(player.max_energy),"enemy_health":maxi(0,int(enemy.health)),"enemy_max_health":int(enemy.max_health),"enemy_energy":maxi(0,int(enemy.energy)),"enemy_max_energy":int(enemy.max_energy),"player_status":_status_text(player),"enemy_status":_status_text(enemy)}

func _action_with_orientation(type_id: String, round_value: int, text: String, attacker: Dictionary, defender: Dictionary, technique: String, player_is_attacker: bool) -> Dictionary:
    var player: Dictionary = attacker if player_is_attacker else defender
    var enemy: Dictionary = defender if player_is_attacker else attacker
    var action := _snapshot_action(type_id, round_value, text, player, enemy, technique)
    action["actor"] = "player" if player_is_attacker else "enemy"
    return action

func _status_text(combatant: Dictionary) -> String:
    var values: Array[String] = []
    if int(combatant.get("bleeding", 0)) > 0: values.append("Sangrado")
    if int(combatant.get("stunned", 0)) > 0: values.append("Aturdido")
    if int(combatant.get("knocked_down", 0)) > 0: values.append("Derribado")
    if int(combatant.get("blind", 0)) > 0: values.append("Cegado")
    if int(combatant.get("armor_break", 0)) > 0: values.append("Armadura rota")
    if int(combatant.get("attack_buff", 0)) < 0: values.append("Desarmado")
    return "Normal" if values.is_empty() else ", ".join(values)

func _status_from_technique(technique: Dictionary) -> String:
    if int(technique.get("bleed", 0)) > 0: return "sangrado"
    if int(technique.get("knockdown", 0)) > 0: return "derribo"
    if int(technique.get("stun", 0)) > 0: return "aturdimiento"
    if int(technique.get("armor_break", 0)) > 0: return "armadura rota"
    if int(technique.get("blind", 0)) > 0: return "ceguera"
    if int(technique.get("weaken", 0)) > 0: return "desarme"
    return ""

func _summarize_techniques(actions: Array[Dictionary]) -> Dictionary:
    var stats: Dictionary = {}
    for action in actions:
        if str(action.get("actor", "")) != "player": continue
        var technique_id := str(action.get("technique", ""))
        if technique_id.is_empty() or not TECHNIQUES.has(technique_id): continue
        if not stats.has(technique_id): stats[technique_id] = {"name":get_technique(technique_id).get("name", technique_id),"uses":0,"damage":0}
        stats[technique_id]["uses"] = int(stats[technique_id].get("uses", 0)) + 1
        stats[technique_id]["damage"] = int(stats[technique_id].get("damage", 0)) + int(action.get("damage", 0))
    return stats

func _summarize_statuses(actions: Array[Dictionary]) -> Dictionary:
    var stats: Dictionary = {}
    for action in actions:
        if str(action.get("actor", "")) != "player": continue
        var status := str(action.get("applied_status", ""))
        if status.is_empty(): continue
        stats[status] = int(stats.get(status, 0)) + 1
    return stats
