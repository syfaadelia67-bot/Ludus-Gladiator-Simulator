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

const BASIC_ATTACK := {
    "id":"basic_attack", "name":"Ataque básico", "energy_cost":8,
    "damage_multiplier":1.0, "accuracy_bonus":0
}

const BEAST_ABILITIES: Dictionary = {
    "bite": {"id":"bite","name":"Mordida","energy_cost":9,"damage_multiplier":1.0,"accuracy_bonus":5,"bleed_chance":0.20},
    "pounce": {"id":"pounce","name":"Abalanzarse","energy_cost":16,"damage_multiplier":1.25,"accuracy_bonus":-4,"stun_chance":0.30},
    "maul": {"id":"maul","name":"Desgarrar","energy_cost":20,"damage_multiplier":1.5,"accuracy_bonus":-9,"bleed_chance":0.45},
    "gore": {"id":"gore","name":"Embestida","energy_cost":18,"damage_multiplier":1.35,"accuracy_bonus":-6,"defense_reduction":3}
}

var last_result: Dictionary = {}
var last_combat_day: int = -1
var next_battle_config: Dictionary = {
    "energy_rule":"balanced",
    "surrender_threshold":20,
    "allow_finisher":true,
    "abilities":[],
    "tactical_plan":[]
}

func get_tactic_ids() -> Array[String]:
    var result: Array[String] = []
    for value in TACTICS.keys():
        result.append(str(value))
    return result

func get_tactic_name(tactic_id: String) -> String:
    return str(TACTICS.get(tactic_id, tactic_id.capitalize()))

func get_technique_ids() -> Array[String]:
    return get_ability_ids()

func get_technique(technique_id: String) -> Dictionary:
    return get_ability(technique_id)

func get_ability_ids() -> Array[String]:
    var result: Array[String] = ["basic_attack"]
    for entry in DataRepository.abilities:
        if entry is Dictionary:
            result.append(str(entry.get("id", "")))
    return result

func get_ability(ability_id: String, level: int = 1) -> Dictionary:
    if ability_id == "basic_attack":
        return BASIC_ATTACK.duplicate(true)
    if BEAST_ABILITIES.has(ability_id):
        return BEAST_ABILITIES[ability_id].duplicate(true)
    for entry in DataRepository.abilities:
        if entry is Dictionary and str(entry.get("id", "")) == ability_id:
            var result: Dictionary = entry.duplicate(true)
            var levels: Dictionary = result.get("levels", {})
            var level_data: Dictionary = levels.get(str(clampi(level, 1, 2)), {}).duplicate(true)
            result.merge(level_data, true)
            result["level"] = clampi(level, 1, 2)
            return result
    return {}

func configure_next_battle(config: Dictionary) -> void:
    next_battle_config = next_battle_config.merged(config, true)

func get_current_event_type() -> String:
    if GameState.day % 7 == 0:
        return "official"
    if GameState.day % 5 == 0:
        return "beast_hunt"
    if GameState.day % 3 == 0:
        return "underground"
    return "none"

func get_current_event_name() -> String:
    match get_current_event_type():
        "official": return "Torneo oficial de la arena"
        "beast_hunt": return "Cacería de bestias del anfiteatro"
        "underground": return "Combate clandestino del bajo mundo"
        _: return "No hay combates programados hoy"

func get_current_event_details() -> Dictionary:
    var event_type := get_current_event_type()
    if event_type == "official":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Duelo reglamentado contra otro gladiador.","risk":"Heridas moderadas","reward":"Denarios + reputación","team_size":1,"opponent_class":"gladiator"}
    if event_type == "beast_hunt":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Supervivencia contra una bestia.","risk":"Heridas graves y sangrado","reward":"Gran premio + reputación","team_size":1,"opponent_class":"beast"}
    if event_type == "underground":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Sin árbitros ni protección oficial.","risk":"Heridas graves","reward":"Más denarios","team_size":1,"opponent_class":"gladiator"}
    return {"type":"none","name":get_current_event_name(),"rules":get_next_event_summary(),"risk":"Sin combate","reward":"—","team_size":0,"opponent_class":"none"}

func get_next_event_summary() -> String:
    var next_underground := GameState.day + (3 - GameState.day % 3)
    var next_beast := GameState.day + (5 - GameState.day % 5)
    var next_official := GameState.day + (7 - GameState.day % 7)
    return "Próximo clandestino: día %d. Bestias: día %d. Oficial: día %d." % [next_underground, next_beast, next_official]

func simulate_duel(gladiator_id: String, tactic: String = "balanced") -> Dictionary:
    var event_type := get_current_event_type()
    if event_type == "none":
        combat_failed.emit("Hoy no hay combates. %s" % get_next_event_summary())
        return {}
    if last_combat_day == GameState.day:
        combat_failed.emit("El ludus ya combatió hoy.")
        return {}
    if not TACTICS.has(tactic):
        combat_failed.emit("La táctica seleccionada no existe.")
        return {}
    var fighter = RosterManager.get_person(gladiator_id)
    if fighter == null or fighter.role != "gladiator":
        combat_failed.emit("Seleccioná un gladiador válido.")
        return {}
    if not fighter.is_available_for_combat():
        combat_failed.emit("El gladiador no está disponible.")
        return {}

    var player := _build_combatant(fighter, tactic)
    var enemy := _build_enemy(fighter, event_type)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var actions: Array[Dictionary] = []
    var combat_log: Array[String] = []
    var round_value := 0
    var surrendered := false

    _record_action(actions, _snapshot("intro", 0, "%s contra %s" % [player.name, enemy.name], player, enemy, "", "system"))
    while int(player.health) > 0 and int(enemy.health) > 0 and round_value < 30:
        round_value += 1
        _tick_statuses(player)
        _tick_statuses(enemy)
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
            _record_action(actions, _snapshot("surrender", round_value, "%s se rinde" % fighter.display_name, player, enemy, "surrender", "player"))
            break
        player.energy = mini(int(player.max_energy), int(player.energy) + _energy_regeneration())
        enemy.energy = mini(int(enemy.max_energy), int(enemy.energy) + 7)

    var victory := int(enemy.health) <= 0 and int(player.health) > 0 and not surrendered
    var reward := 0
    var reputation := 0
    if victory:
        var reward_multiplier := 1.0
        if event_type == "underground": reward_multiplier = 1.35
        elif event_type == "beast_hunt": reward_multiplier = 1.55
        reward = int(round((70 + int(enemy.attack) * 3) * reward_multiplier))
        reputation = 0 if event_type == "underground" else (5 if event_type == "beast_hunt" else 3)
        GameState.denarii += reward
        GameState.reputation += reputation

    fighter.fatigue = mini(100, int(fighter.fatigue) + 8 + floori(float(round_value) / 2.0))
    var injury := _resolve_injury(fighter, player, victory, surrendered, rng, event_type)
    PersonalityManager.register_combat_result(fighter, victory, surrendered, fighter.injury_severity)
    EconomyManager.register_combat_result(victory)
    var tournament_result: Dictionary = {}
    if event_type == "official":
        tournament_result = TournamentManager.register_combat_result(fighter.id, victory)

    _record_action(actions, _snapshot("result", round_value, "VICTORIA" if victory else ("RENDICIÓN" if surrendered else "DERROTA"), player, enemy, "", "system"))
    last_combat_day = GameState.day
    last_result = {
        "event_type":event_type,"event_name":get_current_event_name(),"event_details":get_current_event_details(),"victory":victory,"surrendered":surrendered,
        "rounds":round_value,"fighter":fighter.display_name,"fighter_id":fighter.id,"enemy":enemy.name,"enemy_kind":enemy.get("kind", "gladiator"),"tactic":tactic,
        "player_health":maxi(0,int(player.health)),"player_max_health":int(player.max_health),"player_energy":maxi(0,int(player.energy)),"player_max_energy":int(player.max_energy),
        "enemy_health":maxi(0,int(enemy.health)),"enemy_max_health":int(enemy.max_health),"enemy_energy":maxi(0,int(enemy.energy)),"enemy_max_energy":int(enemy.max_energy),
        "reward":reward,"reputation":reputation,"injury":injury,"injury_days":fighter.injury_days,"tournament":tournament_result,
        "actions":actions,"ability_stats":_summarize_abilities(actions),"technique_stats":_summarize_abilities(actions),"status_stats":_summarize_statuses(actions),"log":combat_log
    }
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    combat_finished.emit(last_result)
    return last_result

func _build_combatant(person, tactic: String) -> Dictionary:
    var equipment: Dictionary = EquipmentManager.get_equipped_stats(person)
    var progression: Dictionary = GladiatorProgressionManager.get_modifiers(person.id)
    var record: Dictionary = GladiatorProgressionManager.get_record(person.id)
    var attack: int = int(person.get_base_attack()) + int(equipment.get("power", 0)) + int(progression.get("attack_bonus", 0))
    var defense: int = int(person.get_base_defense()) + int(equipment.get("defense", 0)) + int(progression.get("defense_bonus", 0))
    var accuracy: int = 55 + int(person.agility) * 3 + int(person.technique) + int(progression.get("accuracy_bonus", 0))
    if tactic == "aggressive":
        attack = int(attack * 1.18)
        defense = int(defense * 0.86)
    elif tactic == "defensive":
        defense = int(defense * 1.24)
        attack = int(attack * 0.90)
    elif tactic == "careful":
        accuracy += 12
    var abilities: Dictionary = record.get("abilities", {}).duplicate(true)
    var plan: Array = next_battle_config.get("tactical_plan", record.get("tactical_plan", [])).duplicate(true)
    return _combatant_base(person.display_name, "gladiator", person.get_max_health(), person.get_max_energy(), attack, defense, accuracy, abilities, plan)

func _build_enemy(person, event_type: String) -> Dictionary:
    var tier := maxi(1, floori(float(person.strength + person.agility + person.endurance + person.technique) / 10.0)) + (1 if event_type == "official" else 0)
    if event_type == "beast_hunt":
        return _build_beast(tier)
    var abilities := {"precise_strike":1, "feint":1, "opportunity_strike":1, "throw_sand":1}
    var plan := [
        {"ability_id":"opportunity_strike","condition":"target_vulnerable"},
        {"ability_id":"throw_sand","condition":"opening"},
        {"ability_id":"feint","condition":"always"},
        {"ability_id":"precise_strike","condition":"always"}
    ]
    return _combatant_base(("Campeón oficial" if event_type == "official" else "Luchador clandestino") + " nivel %d" % tier, "gladiator", 78+tier*20, 72+tier*9, 15+tier*5, 8+tier*4, 58+tier*3, abilities, plan)

func _build_beast(tier: int) -> Dictionary:
    var archetype := GameState.day % 3
    if archetype == 0:
        return _combatant_base("Lobo de Numidia nivel %d" % tier, "wolf", 68+tier*17, 90+tier*8, 16+tier*5, 5+tier*3, 72+tier*2, {"bite":1,"pounce":1}, [])
    if archetype == 1:
        return _combatant_base("Jabalí de guerra nivel %d" % tier, "boar", 96+tier*22, 70+tier*7, 18+tier*5, 10+tier*4, 58+tier*2, {"bite":1,"gore":1}, [])
    return _combatant_base("León del Atlas nivel %d" % tier, "lion", 84+tier*20, 82+tier*8, 20+tier*6, 7+tier*3, 66+tier*3, {"bite":1,"pounce":1,"maul":1}, [])

func _combatant_base(name_value: String, kind: String, health: int, energy: int, attack: int, defense: int, accuracy: int, abilities: Dictionary, plan: Array) -> Dictionary:
    return {"name":name_value,"kind":kind,"health":health,"max_health":health,"energy":energy,"max_energy":energy,"attack":attack,"defense":defense,"base_defense":defense,"accuracy":accuracy,"abilities":abilities,"tactical_plan":plan,"bleeding":0,"blind":0,"stunned":0,"entangled":0,"defense_penalty":0,"evasion_penalty":0,"vulnerable":false,"opened":false,"last_action":"","lost_action":false}

func _attack(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator, actions: Array[Dictionary], combat_log: Array[String], round_value: int, player_attacks: bool) -> void:
    if int(attacker.get("stunned", 0)) > 0 or bool(attacker.get("lost_action", false)):
        attacker.lost_action = false
        _record_action(actions, _oriented_snapshot("skip", round_value, "%s pierde su acción." % attacker.name, attacker, defender, "", player_attacks))
        return
    var ability_id := _choose_ability(attacker, defender, round_value)
    var ability_level := int(attacker.get("abilities", {}).get(ability_id, 1))
    var ability := get_ability(ability_id, ability_level)
    if ability.is_empty():
        ability = BASIC_ATTACK.duplicate(true)
        ability_id = "basic_attack"
    var cost := int(ability.get("energy_cost", 0))
    if int(attacker.energy) < cost:
        attacker.energy = mini(int(attacker.max_energy), int(attacker.energy) + 14)
        attacker.last_action = "recover"
        _record_action(actions, _oriented_snapshot("recover", round_value, "%s recupera energía." % attacker.name, attacker, defender, "recover", player_attacks))
        return
    attacker.energy = int(attacker.energy) - cost
    attacker.last_action = ability_id

    if ability_id == "feint":
        defender.defense_penalty = maxi(int(defender.get("defense_penalty", 0)), int(ability.get("defense_reduction", 0)))
        defender.vulnerable = true
        if rng.randf() <= float(ability.get("waste_enemy_action_chance", 0.0)):
            defender.lost_action = true
        _record_action(actions, _ability_snapshot("effect", round_value, "%s usa Finta y abre la defensa rival." % attacker.name, attacker, defender, ability_id, player_attacks, "vulnerable"))
        return

    var hit_chance := clampi(int(attacker.accuracy) + int(ability.get("accuracy_bonus", 0)) - int(attacker.get("blind", 0)) - int(attacker.get("evasion_penalty", 0)), 18, 96)
    if rng.randi_range(1, 100) > hit_chance:
        _record_action(actions, _oriented_snapshot("miss", round_value, "%s falla %s." % [attacker.name, ability.get("name", ability_id)], attacker, defender, ability_id, player_attacks))
        return

    var damage_multiplier := float(ability.get("damage_multiplier", ability.get("damage_multiplier_per_hit", 0.0)))
    var hits := int(ability.get("hits", 1))
    var total_damage := 0
    if damage_multiplier > 0.0:
        for _hit in range(hits):
            var effective_defense := maxi(0, int(defender.defense) - int(defender.get("defense_penalty", 0)))
            var penetration := float(ability.get("armor_penetration", 0.0))
            effective_defense = int(round(effective_defense * (1.0 - penetration)))
            var damage := maxi(1, int(round(int(attacker.attack) * damage_multiplier)) - floori(float(effective_defense) / 2.0))
            defender.health = int(defender.health) - damage
            total_damage += damage

    _apply_ability_effects(ability, attacker, defender, rng)
    var status := _status_from_ability(ability)
    var action := _ability_snapshot("hit", round_value, "%s usa %s y causa %d de daño." % [attacker.name, ability.get("name", ability_id), total_damage], attacker, defender, ability_id, player_attacks, status)
    action["damage"] = total_damage
    action["ability_level"] = ability_level
    _record_action(actions, action)
    combat_log.append(str(action.text))

func _choose_ability(attacker: Dictionary, defender: Dictionary, round_value: int) -> String:
    var abilities: Dictionary = attacker.get("abilities", {})
    var plan: Array = attacker.get("tactical_plan", [])
    for order in plan:
        if not order is Dictionary:
            continue
        var ability_id := str(order.get("ability_id", ""))
        if not abilities.has(ability_id):
            continue
        if _condition_matches(str(order.get("condition", "always")), attacker, defender, round_value):
            return ability_id
    if str(attacker.get("kind", "gladiator")) != "gladiator" and not abilities.is_empty():
        var keys := abilities.keys()
        return str(keys[randi_range(0, keys.size() - 1)])
    return "basic_attack"

func _condition_matches(condition: String, attacker: Dictionary, defender: Dictionary, round_value: int) -> bool:
    var self_health_ratio := float(maxi(0, int(attacker.health))) / float(maxi(1, int(attacker.max_health)))
    var self_energy_ratio := float(maxi(0, int(attacker.energy))) / float(maxi(1, int(attacker.max_energy)))
    var enemy_energy_ratio := float(maxi(0, int(defender.energy))) / float(maxi(1, int(defender.max_energy)))
    match condition:
        "opening": return round_value == 1
        "target_vulnerable": return bool(defender.get("vulnerable", false)) or int(defender.get("stunned", 0)) > 0 or int(defender.get("blind", 0)) > 0 or int(defender.get("entangled", 0)) > 0
        "target_guarding": return str(defender.get("last_action", "")) == "guard"
        "target_low_energy": return enemy_energy_ratio <= 0.30
        "self_low_health": return self_health_ratio <= 0.35
        "self_low_energy": return self_energy_ratio <= 0.30
        "after_defense": return str(attacker.get("last_action", "")) in ["block", "dodge"]
        _: return true

func _apply_ability_effects(ability: Dictionary, attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator) -> void:
    if rng.randf() <= float(ability.get("bleed_chance", 0.0)):
        defender.bleeding = maxi(int(defender.get("bleeding", 0)), 2)
    if rng.randf() <= float(ability.get("stun_chance", 0.0)):
        defender.stunned = maxi(int(defender.get("stunned", 0)), 1)
        defender.vulnerable = true
    if rng.randf() <= float(ability.get("blind_chance", 0.0)):
        defender.blind = maxi(int(defender.get("blind", 0)), int(ability.get("blind_duration", 1)) * 12)
        defender.vulnerable = true
    if rng.randf() <= float(ability.get("entangle_chance", 0.0)):
        defender.entangled = maxi(int(defender.get("entangled", 0)), int(ability.get("entangle_duration", 1)))
        defender.evasion_penalty = maxi(int(defender.get("evasion_penalty", 0)), 12)
        defender.vulnerable = true
    if rng.randf() <= float(ability.get("enemy_action_loss_chance", 0.0)):
        defender.lost_action = true
    if int(ability.get("defense_reduction", 0)) > 0:
        defender.defense_penalty = maxi(int(defender.get("defense_penalty", 0)), int(ability.get("defense_reduction", 0)))
    if int(ability.get("evasion_reduction", 0)) > 0:
        defender.evasion_penalty = maxi(int(defender.get("evasion_penalty", 0)), int(ability.get("evasion_reduction", 0)))
    if bool(ability.get("retain_initiative_on_hit", false)):
        defender.lost_action = true
    if int(ability.get("recovery_defense_penalty", 0)) > 0:
        attacker.defense_penalty = maxi(int(attacker.get("defense_penalty", 0)), int(ability.get("recovery_defense_penalty", 0)))
        attacker.vulnerable = true

func _tick_statuses(combatant: Dictionary) -> void:
    combatant.stunned = maxi(0, int(combatant.get("stunned", 0)) - 1)
    combatant.entangled = maxi(0, int(combatant.get("entangled", 0)) - 1)
    combatant.blind = maxi(0, int(combatant.get("blind", 0)) - 5)
    combatant.defense_penalty = maxi(0, int(combatant.get("defense_penalty", 0)) - 1)
    combatant.evasion_penalty = maxi(0, int(combatant.get("evasion_penalty", 0)) - 2)
    combatant.vulnerable = int(combatant.stunned) > 0 or int(combatant.entangled) > 0 or int(combatant.blind) > 0 or int(combatant.defense_penalty) > 0

func _apply_bleeding(combatant: Dictionary, opponent: Dictionary, actions: Array[Dictionary], round_value: int, player_side: bool) -> void:
    if int(combatant.get("bleeding", 0)) <= 0:
        return
    var damage := maxi(1, floori(float(int(combatant.max_health)) / 30.0))
    combatant.health = int(combatant.health) - damage
    combatant.bleeding = maxi(0, int(combatant.bleeding) - 1)
    var action := _oriented_snapshot("status_damage", round_value, "%s pierde %d por sangrado." % [combatant.name, damage], combatant, opponent, "bleeding", player_side)
    action["damage"] = damage
    action["applied_status"] = "sangrado"
    _record_action(actions, action)

func _should_surrender(fighter, player: Dictionary, tactic: String, rng: RandomNumberGenerator) -> bool:
    var threshold := int(next_battle_config.get("surrender_threshold", 20))
    if threshold <= 0 or int(player.health) <= 0:
        return false
    var health_percent := floori(100.0 * float(player.health) / float(maxi(1, int(player.max_health))))
    if health_percent > threshold:
        return false
    var chance := 35 + maxi(0, 45 - int(fighter.morale))
    if get_current_event_type() == "beast_hunt": chance += 8
    if tactic == "aggressive": chance -= 14
    elif tactic == "careful": chance += 8
    return rng.randi_range(1, 100) <= clampi(chance, 8, 88)

func _energy_regeneration() -> int:
    var rule := str(next_battle_config.get("energy_rule", "balanced"))
    if rule == "conserve": return 9
    if rule == "spend": return 4
    return 6

func _resolve_injury(fighter, player: Dictionary, victory: bool, surrendered: bool, rng: RandomNumberGenerator, event_type: String) -> String:
    var health_ratio := float(maxi(0, int(player.health))) / float(maxi(1, int(player.max_health)))
    var chance := 10
    if event_type == "underground": chance += 10
    elif event_type == "beast_hunt": chance += 18
    if health_ratio <= 0.0: chance = 80
    elif health_ratio < 0.25: chance += 42
    if surrendered: chance -= 15
    if victory: chance -= 4
    if rng.randi_range(1, 100) > clampi(chance, 2, 92): return ""
    var severity := 2 if health_ratio < 0.25 or event_type == "beast_hunt" else 1
    var injury_name := "Desgarro de bestia" if event_type == "beast_hunt" else ("Herida profunda" if severity == 2 else "Contusión")
    var days := severity * 2 + rng.randi_range(0, severity * 2)
    fighter.apply_injury(injury_name, severity, days)
    return "%s; recuperación: %d día(s)" % [injury_name, days]

func _record_action(actions: Array[Dictionary], action: Dictionary) -> void:
    actions.append(action)
    combat_turn.emit(action)

func _snapshot(type_id: String, round_value: int, text: String, player: Dictionary, enemy: Dictionary, ability: String, actor: String) -> Dictionary:
    return {"type":type_id,"round":round_value,"text":text,"ability":ability,"technique":ability,"actor":actor,"player_health":maxi(0,int(player.health)),"player_max_health":int(player.max_health),"player_energy":maxi(0,int(player.energy)),"player_max_energy":int(player.max_energy),"enemy_health":maxi(0,int(enemy.health)),"enemy_max_health":int(enemy.max_health),"enemy_energy":maxi(0,int(enemy.energy)),"enemy_max_energy":int(enemy.max_energy),"enemy_kind":enemy.get("kind", "gladiator")}

func _oriented_snapshot(type_id: String, round_value: int, text: String, attacker: Dictionary, defender: Dictionary, ability: String, player_attacks: bool) -> Dictionary:
    var player := attacker if player_attacks else defender
    var enemy := defender if player_attacks else attacker
    return _snapshot(type_id, round_value, text, player, enemy, ability, "player" if player_attacks else "enemy")

func _ability_snapshot(type_id: String, round_value: int, text: String, attacker: Dictionary, defender: Dictionary, ability: String, player_attacks: bool, status: String) -> Dictionary:
    var action := _oriented_snapshot(type_id, round_value, text, attacker, defender, ability, player_attacks)
    action["applied_status"] = status
    return action

func _status_from_ability(ability: Dictionary) -> String:
    if float(ability.get("bleed_chance", 0.0)) > 0.0: return "sangrado"
    if float(ability.get("stun_chance", 0.0)) > 0.0: return "aturdimiento"
    if float(ability.get("blind_chance", 0.0)) > 0.0: return "ceguera"
    if float(ability.get("entangle_chance", 0.0)) > 0.0: return "enredado"
    if int(ability.get("defense_reduction", 0)) > 0: return "defensa reducida"
    return ""

func _summarize_abilities(actions: Array[Dictionary]) -> Dictionary:
    var stats: Dictionary = {}
    for action in actions:
        if not action is Dictionary or str(action.get("actor", "")) != "player":
            continue
        var ability_id := str(action.get("ability", ""))
        if ability_id.is_empty() or ability_id in ["recover", "bleeding"]:
            continue
        if not stats.has(ability_id):
            stats[ability_id] = {"name":get_ability(ability_id, int(action.get("ability_level", 1))).get("name", ability_id),"uses":0,"damage":0}
        stats[ability_id]["uses"] = int(stats[ability_id]["uses"]) + 1
        stats[ability_id]["damage"] = int(stats[ability_id]["damage"]) + int(action.get("damage", 0))
    return stats

func _summarize_statuses(actions: Array[Dictionary]) -> Dictionary:
    var stats: Dictionary = {}
    for action in actions:
        if not action is Dictionary:
            continue
        var status := str(action.get("applied_status", ""))
        if not status.is_empty():
            stats[status] = int(stats.get(status, 0)) + 1
    return stats
