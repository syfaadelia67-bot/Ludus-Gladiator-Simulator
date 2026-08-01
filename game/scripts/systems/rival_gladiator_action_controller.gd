extends Node

signal rival_gladiator_action_completed(result: Dictionary)
signal rival_gladiator_action_failed(reason: String)

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")
const PROFILE_KEY := "unique_gladiator_profiles"

func get_rival_gladiators() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for rival in RivalManager.rivals:
        var profiles: Dictionary = rival.get(PROFILE_KEY, {})
        for gladiator_id in profiles.keys():
            var profile: Dictionary = profiles[gladiator_id].duplicate(true)
            var entry := DataRepository.get_unique_gladiator(str(gladiator_id))
            if entry.is_empty():
                continue
            _ensure_profile_defaults(profile, entry)
            profile["gladiator_id"] = str(gladiator_id)
            profile["name"] = str(entry.get("name", gladiator_id))
            profile["origin"] = str(entry.get("origin", "Desconocido"))
            profile["rival_id"] = str(rival.get("id", ""))
            profile["rival_name"] = str(rival.get("name", "Casa rival"))
            profile["intel_level"] = int(rival.get("intel", 0))
            profile["visible"] = _visible_profile(profile, int(rival.get("intel", 0)))
            result.append(profile)
    result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")) < str(b.get("name", "")))
    return result

func undermine_loyalty(gladiator_id: String) -> Dictionary:
    var located := _locate(gladiator_id)
    if located.is_empty():
        return _fail("El gladiador rival no está disponible.")
    if RosterManager.intelligence_points < 10:
        return _fail("Se necesitan 10 puntos de inteligencia.")
    if not GameState.spend_denarii(45):
        return _fail("Se necesitan 45 denarios para financiar contactos.")
    RosterManager.intelligence_points -= 10
    var profile: Dictionary = located.profile
    var reduction := 8 + absi(hash("loyalty|%s|%d" % [gladiator_id, GameState.get_week()])) % 8
    profile["loyalty"] = maxi(0, int(profile.get("loyalty", 55)) - reduction)
    profile["last_action_week"] = GameState.get_week()
    _store_profile(located.rival_id, gladiator_id, profile)
    return _complete("undermine_loyalty", gladiator_id, located.rival_id, "La lealtad cayó %d puntos." % reduction)

func sabotage_training(gladiator_id: String) -> Dictionary:
    var located := _locate(gladiator_id)
    if located.is_empty():
        return _fail("El gladiador rival no está disponible.")
    if RosterManager.intelligence_points < 16:
        return _fail("Se necesitan 16 puntos de inteligencia.")
    if not GameState.spend_denarii(70):
        return _fail("Se necesitan 70 denarios para ejecutar el sabotaje.")
    RosterManager.intelligence_points -= 16
    var profile: Dictionary = located.profile
    var loss := mini(int(profile.get("experience", 0)), 18 + absi(hash("sabotage|%s|%d" % [gladiator_id, GameState.get_week()])) % 18)
    profile["experience"] = maxi(0, int(profile.get("experience", 0)) - loss)
    profile["training_disrupted_until"] = GameState.get_week() + 1
    profile["last_action_week"] = GameState.get_week()
    _store_profile(located.rival_id, gladiator_id, profile)
    return _complete("sabotage_training", gladiator_id, located.rival_id, "El entrenamiento rival perdió %d puntos de experiencia." % loss)

func contract_gladiator(gladiator_id: String) -> Dictionary:
    var located := _locate(gladiator_id)
    if located.is_empty():
        return _fail("El gladiador rival no está disponible.")
    var profile: Dictionary = located.profile
    if int(profile.get("loyalty", 55)) > 35:
        return _fail("La lealtad hacia su casa debe bajar a 35 o menos.")
    if RosterManager.intelligence_points < 25:
        return _fail("Se necesitan 25 puntos de inteligencia para negociar en secreto.")
    var entry := DataRepository.get_unique_gladiator(gladiator_id)
    var price := int(ceil(float(entry.get("price", 300)) * 1.40))
    if not RosterManager.has_capacity():
        return _fail("No hay capacidad disponible en el ludus.")
    if not GameState.spend_denarii(price):
        return _fail("Se necesitan %d denarios para comprar el contrato." % price)
    RosterManager.intelligence_points -= 25
    var person = PERSON_SCRIPT.new(entry)
    person.role = "gladiator"
    person.job = "idle"
    if not RosterManager.add_person(person):
        GameState.add_denarii(price)
        RosterManager.intelligence_points += 25
        return _fail("No fue posible incorporar al gladiador.")
    _remove_from_rival(located.rival_id, gladiator_id)
    var state: Dictionary = UniqueGladiatorManager.states.get(gladiator_id, {})
    state["status"] = "player"
    state["rival_id"] = ""
    state["acquired_week"] = GameState.get_week()
    UniqueGladiatorManager.states[gladiator_id] = state
    UniqueGladiatorManager.unique_gladiator_acquired.emit(gladiator_id)
    UniqueGladiatorManager.unique_gladiators_changed.emit()
    return _complete("contract", gladiator_id, located.rival_id, "%s se incorporó al ludus por %d denarios." % [person.display_name, price])

func _visible_profile(profile: Dictionary, intel: int) -> Dictionary:
    var visible := {"name":profile.get("name", "Gladiador"),"level":profile.get("level", 1),"loyalty_band":_loyalty_band(int(profile.get("loyalty", 55)))}
    if intel >= 20:
        visible["wins"] = int(profile.get("wins", 0))
        visible["losses"] = int(profile.get("losses", 0))
        visible["experience_band"] = _experience_band(int(profile.get("experience", 0)))
    if intel >= 45:
        visible["loyalty"] = int(profile.get("loyalty", 55))
        visible["experience"] = int(profile.get("experience", 0))
        visible["contract_price"] = int(ceil(float(DataRepository.get_unique_gladiator(str(profile.get("gladiator_id", ""))).get("price", 300)) * 1.40))
    return visible

func _locate(gladiator_id: String) -> Dictionary:
    for rival in RivalManager.rivals:
        var profiles: Dictionary = rival.get(PROFILE_KEY, {})
        if profiles.has(gladiator_id):
            var profile: Dictionary = profiles[gladiator_id].duplicate(true)
            _ensure_profile_defaults(profile, DataRepository.get_unique_gladiator(gladiator_id))
            return {"rival_id":str(rival.get("id", "")),"profile":profile}
    return {}

func _ensure_profile_defaults(profile: Dictionary, entry: Dictionary) -> void:
    profile["loyalty"] = clampi(int(profile.get("loyalty", entry.get("loyalty", 55))), 0, 100)
    profile["last_action_week"] = maxi(0, int(profile.get("last_action_week", 0)))
    profile["training_disrupted_until"] = maxi(0, int(profile.get("training_disrupted_until", 0)))

func _store_profile(rival_id: String, gladiator_id: String, profile: Dictionary) -> void:
    for rival in RivalManager.rivals:
        if str(rival.get("id", "")) != rival_id:
            continue
        var profiles: Dictionary = rival.get(PROFILE_KEY, {})
        profiles[gladiator_id] = profile
        rival[PROFILE_KEY] = profiles
        RivalManager.rivals_changed.emit()
        return

func _remove_from_rival(rival_id: String, gladiator_id: String) -> void:
    for rival in RivalManager.rivals:
        if str(rival.get("id", "")) != rival_id:
            continue
        var assigned: Array = rival.get("unique_gladiators", [])
        assigned.erase(gladiator_id)
        rival["unique_gladiators"] = assigned
        var profiles: Dictionary = rival.get(PROFILE_KEY, {})
        profiles.erase(gladiator_id)
        rival[PROFILE_KEY] = profiles
        RivalManager.rivals_changed.emit()
        return

func _loyalty_band(value: int) -> String:
    return "quebrada" if value <= 20 else ("inestable" if value <= 35 else ("moderada" if value <= 65 else "firme"))

func _experience_band(value: int) -> String:
    return "cerca de subir" if value >= 40 else ("en progreso" if value >= 15 else "inicial")

func _complete(action: String, gladiator_id: String, rival_id: String, message: String) -> Dictionary:
    var result := {"success":true,"action":action,"gladiator_id":gladiator_id,"rival_id":rival_id,"message":message,"week":GameState.get_week()}
    GameState.resources_changed.emit()
    rival_gladiator_action_completed.emit(result)
    return result

func _fail(reason: String) -> Dictionary:
    rival_gladiator_action_failed.emit(reason)
    return {"success":false,"reason":reason}
