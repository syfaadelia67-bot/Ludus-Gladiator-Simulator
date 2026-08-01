extends "res://scripts/systems/combat_manager_fixed.gd"

const DEMO_FINAL_WEEK := 16

const WEEKLY_INJURIES := {
    1: ["Contusión", "Corte superficial", "Esguince leve"],
    2: ["Herida profunda", "Luxación", "Fractura menor", "Desgarro muscular"],
    3: ["Fractura grave", "Herida crítica", "Desgarro de bestia", "Trauma severo"]
}

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
        return {
            "type":event_type,
            "name":get_event_name_for_week(week),
            "rules":"Duelo decisivo que cierra la campaña de dieciséis semanas.",
            "risk":"Heridas graves",
            "reward":"Victoria o derrota final de campaña",
            "team_size":1,
            "opponent_class":"gladiator",
            "finale":true
        }
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

func simulate_duel(gladiator_id: String, tactic: String = "balanced") -> Dictionary:
    if CampaignManager.campaign_over:
        combat_failed.emit("La campaña terminó. La Arena está disponible solo para consultar resultados e historial.")
        return {}
    if last_combat_day == GameState.day:
        combat_failed.emit("El ludus ya disputó el combate de esta semana.")
        return {}
    return super.simulate_duel(gladiator_id, tactic)

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
