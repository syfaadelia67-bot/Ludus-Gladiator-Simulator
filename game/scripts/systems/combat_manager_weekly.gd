extends "res://scripts/systems/combat_manager_fixed.gd"

func get_current_event_type() -> String:
    var week := GameState.get_week()
    if week % 4 == 0:
        return "official"
    if week % 3 == 0:
        return "beast_hunt"
    if week % 2 == 0:
        return "underground"
    return "exhibition"

func get_current_event_name() -> String:
    match get_current_event_type():
        "official": return "Torneo oficial de la arena"
        "beast_hunt": return "Cacería de bestias del anfiteatro"
        "underground": return "Combate clandestino del bajo mundo"
        _: return "Exhibición semanal del ludus"

func get_current_event_details() -> Dictionary:
    var event_type := get_current_event_type()
    if event_type == "official":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Duelo reglamentado contra otro gladiador.","risk":"Heridas moderadas","reward":"Denarios + reputación","team_size":1,"opponent_class":"gladiator"}
    if event_type == "beast_hunt":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Supervivencia contra una bestia.","risk":"Heridas graves y sangrado","reward":"Gran premio + reputación","team_size":1,"opponent_class":"beast"}
    if event_type == "underground":
        return {"type":event_type,"name":get_current_event_name(),"rules":"Sin árbitros ni protección oficial.","risk":"Heridas graves","reward":"Más denarios","team_size":1,"opponent_class":"gladiator"}
    return {"type":"exhibition","name":get_current_event_name(),"rules":"Duelo de exhibición obligatorio para mantener activo el nombre del ludus.","risk":"Heridas leves o moderadas","reward":"Denarios y experiencia","team_size":1,"opponent_class":"gladiator"}

func get_next_event_summary() -> String:
    return "Semana %d: %s. Cada semana incluye al menos un combate." % [GameState.get_week(), get_current_event_name()]
