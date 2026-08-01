extends "res://scripts/systems/combat_manager_fixed.gd"

const DEMO_FINAL_WEEK := 16

const WEEKLY_INJURIES := {
    1: ["Contusión", "Corte superficial", "Esguince leve"],
    2: ["Herida profunda", "Luxación", "Fractura menor", "Desgarro muscular"],
    3: ["Fractura grave", "Herida crítica", "Desgarro de bestia", "Trauma severo"]
}

var _last_unique_enemy_id := ""
var _last_unique_enemy_rival_id := ""

func get_event_type_for_week(week: int) -> String:
    var resolved_week := maxi(1, week)
    if resolved_week == DEMO_FINAL_WEEK:
        return "demo_finale"
    if resolved_week % 4 == 0:
        return "official"
    if resolved_week % 3 == 0:
        return "beast_hunt"
    if resolved_week % 2 == 0:
        return "underground"
    return "exhibition"

func get_event_name_for_week(week: int) -> String:
    match get_event_type_for_week(week):
        "demo_finale": return "Combate final de la demo"
        "official": return "Torneo oficial de la arena"
        "beast_hunt": return "Cacería de bestias del anfiteatro"
        "underground": return "Combate clandestino del bajo mundo"
        _: return "Exhibición semanal del ludus"

func get_event_details_for_week(week: int) -> Dictionary:
    var event_type := get_event_type_for_week(week)
    if event_type == "demo_finale":
        return {"type":event_type,"name":get_event_name_for_week(week),"rules":"Duelo decisivo que cierra la campaña de dieciséis semanas.","risk":"Heridas graves","reward":"Victoria o derrota final de campaña","team_size":1,"opponent_class":"gladiator","finale":true}
    if event_type == "official":
        return {"type":event_type,"name":get_event_name_for_week(week),"rules":"Duelo reglamentado contra otro gladiador.","risk":"Heridas moderadas","reward":"Denarios + reputación","team_size":1,"opponent_class":"gladiator","finale":false}
    if event_type == "beast_hunt":
        return {"type":event_type,"name":get_event_name_for_week(week),"rules":"Supervivencia contra una bestia.","risk":"Heridas graves y sangrado","reward":"Gran premio + reputación","team_size":1,"opponent_class":"beast","finale":false}
    if event_type == "underground":
        return {"type":event_type,"name":get_event_name_for_week(week),"rules":"Sin árbitros ni protección oficial.","risk":"Heridas graves","reward":"Más denarios","team_size":1,"opponent_class":"gladiator","finale":false}
    return {"type":"exhibition","name":get_event_name_for_week(week),"rules":"Duelo de exhibición obligatorio para mantener activo el nombre del ludus.","risk":"Heridas leves o moderadas","reward":"Denarios y experiencia","team_size":1,"opponent_class":"gladiator","finale":false}

func get_current_event_type() -> String:
    return get_event_type_for_week(GameState.get_week())

func get_current_event_name() -> String:
    return get_event_name_for_week(GameState.get_week())

func get_current_event_details() -> Dictionary:
    return get_event_details_for_week(GameState.get_week())

func get_next_event_summary() -> String:
    return "Semana %d: %s. Cada semana incluye al menos un combate." % [GameState.get_week(), get_current_event_name()]

func get_current_opponent_preview(fighter_id: String = "") -> Dictionary:
    var week := GameState.get_week()
    var event_type := get_event_type_for_week(week)
    if event_type == "beast_hunt":
        return {"known":false,"kind":"beast","title":"Bestia no revelada","description":"La especie y el tamaño se confirmarán al comenzar la cacería."}
    var profile := RivalUniqueGladiatorController.get_opponent_for_week(week, event_type)
    if profile.is_empty():
        return {"known":false,"kind":"generic","title":"Oponente por confirmar","description":"La organización de la Arena todavía no anunció al rival."}
    var gladiator_id := str(profile.get("gladiator_id", ""))
    var entry := DataRepository.get_unique_gladiator(gladiator_id)
    if entry.is_empty():
        return {"known":false,"kind":"generic","title":"Oponente por confirmar","description":"No hay información fiable sobre el combatiente."}
    var level := maxi(1, int(profile.get("level", 1)))
    var rivalry: Dictionary = {}
    if not fighter_id.is_empty():
        rivalry = GladiatorRivalryController.get_rivalry(fighter_id, gladiator_id)
    return {
        "known":true,
        "kind":"unique_gladiator",
        "gladiator_id":gladiator_id,
        "rival_id":str(profile.get("rival_id", "")),
        "name":str(entry.get("name", gladiator_id)),
        "rival_name":str(profile.get("rival_name", "Casa rival")),
        "level":level,
        "origin":str(entry.get("origin", "Desconocido")),
        "strength":int(entry.get("strength", 5)),
        "agility":int(entry.get("agility", 5)),
        "endurance":int(entry.get("endurance", 5)),
        "technique":int(entry.get("technique", 5)),
        "health":int(entry.get("health", 50)) + level * 8,
        "wins":int(profile.get("wins", 0)),
        "losses":int(profile.get("losses", 0)),
        "rivalry":rivalry
    }

func simulate_duel(gladiator_id: String, tactic: String = "balanced") -> Dictionary:
    if not UniqueGladiatorManager.first_purchase_completed or not RosterManager.has_gladiator():
        combat_failed.emit("Primero debés comprar uno de los tres gladiadores iniciales en el Mercado.")
        return {}
    if CampaignManager.campaign_over:
        combat_failed.emit("La campaña terminó. La Arena está disponible solo para consultar resultados e historial.")
        return {}
    if last_combat_day == GameState.day:
        combat_failed.emit("El ludus ya disputó el combate de esta semana.")
        return {}
    _last_unique_enemy_id = ""
    _last_unique_enemy_rival_id = ""
    var result := super.simulate_duel(gladiator_id, tactic)
    if not result.is_empty() and not _last_unique_enemy_id.is_empty():
        result["enemy_unique_gladiator_id"] = _last_unique_enemy_id
        result["enemy_rival_id"] = _last_unique_enemy_rival_id
        last_result["enemy_unique_gladiator_id"] = _last_unique_enemy_id
        last_result["enemy_rival_id"] = _last_unique_enemy_rival_id
        RivalUniqueGladiatorController.register_combat_result(_last_unique_enemy_id, bool(result.get("victory", false)))
    return result

func _build_combatant(person, tactic: String) -> Dictionary:
    var combatant := super._build_combatant(person, tactic)
    var modifiers := GladiatorCareerStateController.get_combat_modifiers(person.id)
    combatant.attack = int(round(float(combatant.attack + int(modifiers.get("attack_bonus", 0))) * float(modifiers.get("attack_multiplier", 1.0))))
    combatant.accuracy = int(combatant.accuracy) + int(modifiers.get("accuracy_bonus", 0))
    var energy_value := int(round(float(combatant.max_energy + int(modifiers.get("energy_bonus", 0))) * float(modifiers.get("energy_multiplier", 1.0))))
    combatant.max_energy = maxi(20, energy_value)
    combatant.energy = combatant.max_energy
    return combatant

func _build_enemy(person, event_type: String) -> Dictionary:
    var profile := RivalUniqueGladiatorController.get_opponent_for_week(GameState.get_week(), event_type)
    if profile.is_empty():
        return super._build_enemy(person, event_type)
    var gladiator_id := str(profile.get("gladiator_id", ""))
    var entry := DataRepository.get_unique_gladiator(gladiator_id)
    if entry.is_empty():
        return super._build_enemy(person, event_type)
    var level := maxi(1, int(profile.get("level", 1)))
    var attack := int(entry.get("strength", 5)) * 2 + int(entry.get("technique", 5)) + level * 3
    var defense := int(entry.get("endurance", 5)) * 2 + int(entry.get("agility", 5)) + level * 2
    var health := int(entry.get("health", 50)) + level * 8
    var energy := 65 + int(entry.get("endurance", 5)) * 4 + level * 3
    var accuracy := 48 + int(entry.get("agility", 5)) * 3 + int(entry.get("technique", 5)) + level
    var abilities := {"precise_strike":1,"feint":1,"opportunity_strike":1,"throw_sand":1}
    var plan := [{"ability_id":"opportunity_strike","condition":"target_vulnerable"},{"ability_id":"throw_sand","condition":"opening"},{"ability_id":"feint","condition":"always"},{"ability_id":"precise_strike","condition":"always"}]
    _last_unique_enemy_id = gladiator_id
    _last_unique_enemy_rival_id = str(profile.get("rival_id", ""))
    return _combatant_base("%s · %s · nivel %d" % [entry.get("name", gladiator_id), profile.get("rival_name", "Casa rival"), level], "unique_gladiator", health, energy, attack, defense, accuracy, abilities, plan)

func _resolve_injury(fighter, player: Dictionary, victory: bool, surrendered: bool, rng: RandomNumberGenerator, event_type: String) -> String:
    var health_ratio := float(maxi(0, int(player.health))) / float(maxi(1, int(player.max_health)))
    var chance := 8
    match event_type:
        "demo_finale": chance += 22
        "beast_hunt": chance += 18
        "underground": chance += 12
        "official": chance += 5
    if health_ratio <= 0.0:
        chance = 88
    elif health_ratio < 0.20:
        chance += 45
    elif health_ratio < 0.40:
        chance += 22
    if surrendered:
        chance -= 14
    if victory:
        chance -= 4
    if rng.randi_range(1, 100) > clampi(chance, 2, 94):
        return ""
    var severity := 1
    if health_ratio <= 0.0 or (health_ratio < 0.15 and event_type in ["beast_hunt", "underground", "demo_finale"]):
        severity = 3
    elif health_ratio < 0.40 or event_type in ["beast_hunt", "underground", "demo_finale"]:
        severity = 2
    var candidates: Array = WEEKLY_INJURIES.get(severity, WEEKLY_INJURIES[1])
    var injury_name := str(candidates[rng.randi_range(0, candidates.size() - 1)])
    if event_type == "beast_hunt" and severity >= 2:
        injury_name = "Desgarro de bestia"
    var recovery_weeks := severity + rng.randi_range(0, severity)
    fighter.apply_injury(injury_name, severity, recovery_weeks)
    return "%s · gravedad %d · recuperación: %d semana(s)" % [injury_name, severity, recovery_weeks]
