extends Node

signal event_started(event: Dictionary)
signal event_resolved(result: Dictionary)
signal events_changed
signal effect_expired(effect: Dictionary)

const EVENTS := {
    "grain_shortage": {
        "title":"Escasez de grano",
        "text":"Los mercaderes anuncian una mala cosecha. El precio del alimento subirá y la finca debe decidir cómo reaccionar.",
        "weight":18,
        "cooldown":8,
        "choices":[
            {"id":"buy_now","label":"Comprar reservas","requirements":{"denarii":120},"effects":{"denarii":-120,"food":55,"reputation":1},"result":"La despensa queda asegurada antes del aumento de precios."},
            {"id":"ration","label":"Racionar durante cinco días","effects":{"morale_all":-4,"timed":{"id":"rationing","name":"Racionamiento","days":5,"food_consumption_multiplier":0.65}},"result":"Las raciones se reducen. Se conserva alimento, pero el ánimo cae."},
            {"id":"ignore","label":"Confiar en las reservas","effects":{"food":-18},"result":"La escasez golpea la finca y parte de las reservas se pierde en compras urgentes."}
        ]
    },
    "wounded_veteran": {
        "title":"Un veterano pide refugio",
        "text":"Un antiguo gladiador llega herido. Ofrece enseñar técnicas de arena a cambio de comida y protección.",
        "weight":14,
        "cooldown":12,
        "choices":[
            {"id":"welcome","label":"Recibirlo como instructor","requirements":{"food":15},"effects":{"food":-15,"training_all":10,"reputation":2,"timed":{"id":"veteran_training","name":"Instructor veterano","days":7,"training_multiplier":1.20}},"result":"El veterano comparte métodos de combate y mejora el entrenamiento."},
            {"id":"pay","label":"Pagar una sola lección","requirements":{"denarii":70},"effects":{"denarii":-70,"training_all":6},"result":"La lección es breve, pero útil para toda la plantilla."},
            {"id":"refuse","label":"Negarle la entrada","effects":{"reputation":-1},"result":"El veterano se marcha hablando con amargura sobre el ludus."}
        ]
    },
    "corrupt_official": {
        "title":"La visita del magistrado",
        "text":"Un funcionario insinúa que una contribución privada facilitaría permisos y contratos futuros.",
        "weight":12,
        "cooldown":14,
        "choices":[
            {"id":"bribe","label":"Entregar 100 denarios","requirements":{"denarii":100},"effects":{"denarii":-100,"reputation":2,"timed":{"id":"official_favor","name":"Favor del magistrado","days":10,"market_discount":0.12}},"result":"El magistrado promete recordar la generosidad del ludus."},
            {"id":"expose","label":"Denunciarlo públicamente","requirements":{"reputation":5},"effects":{"reputation":3,"timed":{"id":"official_hostility","name":"Hostilidad administrativa","days":6,"daily_denarii":-8}},"result":"La denuncia mejora la imagen pública, pero crea enemigos administrativos."},
            {"id":"refuse","label":"Rechazar con prudencia","effects":{},"result":"El funcionario se retira sin obtener nada, aunque no parece satisfecho."}
        ]
    },
    "slave_dispute": {
        "title":"Disputa en los barracones",
        "text":"Dos miembros de la finca se enfrentan por una acusación de robo. El conflicto está afectando a los demás.",
        "weight":16,
        "cooldown":7,
        "choices":[
            {"id":"investigate","label":"Investigar con inteligencia","requirements":{"intelligence":6},"effects":{"intelligence":-6,"morale_all":3,"loyalty_all":2},"result":"La investigación aclara los hechos y refuerza la confianza en la dirección."},
            {"id":"punish","label":"Castigar a ambos","effects":{"morale_all":-5,"loyalty_all":-3,"security":4},"result":"La disciplina se impone, pero el resentimiento aumenta."},
            {"id":"mediate","label":"Mediar personalmente","effects":{"morale_all":1},"result":"La tensión baja sin que el conflicto quede completamente resuelto."}
        ]
    },
    "merchant_offer": {
        "title":"Oferta de un mercader",
        "text":"Un comerciante ofrece un cargamento de mineral de procedencia dudosa a un precio excepcional.",
        "weight":15,
        "cooldown":9,
        "choices":[
            {"id":"buy","label":"Comprar el cargamento","requirements":{"denarii":85},"effects":{"denarii":-85,"ore":28,"timed":{"id":"stolen_goods_risk","name":"Mercancía sospechosa","days":4,"reputation_on_expire":-1}},"result":"El mineral llega a la forja, aunque nadie pregunta de dónde provino."},
            {"id":"report","label":"Informar a las autoridades","effects":{"reputation":2,"denarii":25},"result":"Las autoridades recompensan la información y mejora la reputación del ludus."},
            {"id":"decline","label":"Rechazar la oferta","effects":{},"result":"El comerciante recoge sus bienes y busca otro comprador."}
        ]
    },
    "public_festival": {
        "title":"Festival de la ciudad",
        "text":"La ciudad celebra varios días de juegos. Participar puede aumentar el prestigio, pero exige recursos.",
        "weight":10,
        "cooldown":16,
        "choices":[
            {"id":"sponsor","label":"Patrocinar una exhibición","requirements":{"denarii":160,"gladiators":1},"effects":{"denarii":-160,"reputation":6,"morale_all":4},"result":"La exhibición atrae al público y el nombre del ludus circula por toda la ciudad."},
            {"id":"small_presence","label":"Enviar una delegación","requirements":{"denarii":45},"effects":{"denarii":-45,"reputation":2},"result":"La presencia es modesta, pero suficiente para mantener visibilidad."},
            {"id":"skip","label":"No participar","effects":{"reputation":-1},"result":"Otros ludus ocupan el espacio público dejado libre."}
        ]
    }
}

var pending_event: Dictionary = {}
var active_effects: Array[Dictionary] = []
var history: Array[Dictionary] = []
var cooldowns: Dictionary = {}
var resolved_count: int = 0
var days_without_event: int = 0

func process_day() -> Dictionary:
    _process_active_effects()
    _tick_cooldowns()
    if not pending_event.is_empty():
        return {}
    days_without_event += 1
    var chance := clampf(0.18 + float(days_without_event) * 0.035, 0.18, 0.60)
    if randf() > chance:
        return {}
    var event_id := _pick_event()
    if event_id.is_empty():
        return {}
    pending_event = _build_event(event_id)
    days_without_event = 0
    event_started.emit(pending_event.duplicate(true))
    events_changed.emit()
    return pending_event.duplicate(true)

func resolve_choice(choice_id: String) -> Dictionary:
    if pending_event.is_empty():
        return {"success":false,"reason":"No hay un evento pendiente."}
    var choice := _find_choice(pending_event, choice_id)
    if choice.is_empty():
        return {"success":false,"reason":"La decisión seleccionada no existe."}
    var unmet := get_unmet_requirements(choice)
    if not unmet.is_empty():
        return {"success":false,"reason":unmet}
    _apply_effects(choice.get("effects", {}))
    var event_id := str(pending_event.get("id", ""))
    var result := {
        "success":true,
        "event_id":event_id,
        "title":pending_event.get("title", "Evento"),
        "choice_id":choice_id,
        "choice_label":choice.get("label", choice_id),
        "result":choice.get("result", "La decisión fue aplicada."),
        "day":GameState.day
    }
    history.append(result.duplicate(true))
    if history.size() > 40:
        history.pop_front()
    resolved_count += 1
    cooldowns[event_id] = int(EVENTS.get(event_id, {}).get("cooldown", 7))
    pending_event = {}
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    event_resolved.emit(result)
    events_changed.emit()
    return result

func get_unmet_requirements(choice: Dictionary) -> String:
    var requirements: Dictionary = choice.get("requirements", {})
    if GameState.denarii < int(requirements.get("denarii", 0)):
        return "No hay suficientes denarios."
    if GameState.food < int(requirements.get("food", 0)):
        return "No hay suficiente comida."
    if GameState.reputation < int(requirements.get("reputation", 0)):
        return "La reputación es insuficiente."
    if RosterManager.intelligence_points < int(requirements.get("intelligence", 0)):
        return "No hay suficiente inteligencia acumulada."
    if _count_gladiators() < int(requirements.get("gladiators", 0)):
        return "No hay suficientes gladiadores disponibles."
    return ""

func get_pending_event() -> Dictionary:
    return pending_event.duplicate(true)

func get_active_effects() -> Array:
    return active_effects.duplicate(true)

func get_food_consumption_multiplier() -> float:
    return _multiply_effect("food_consumption_multiplier")

func get_training_multiplier() -> float:
    return _multiply_effect("training_multiplier")

func get_market_discount() -> float:
    var discount := 0.0
    for effect in active_effects:
        discount = maxf(discount, float(effect.get("market_discount", 0.0)))
    return clampf(discount, 0.0, 0.50)

func export_state() -> Dictionary:
    return {"pending_event":pending_event.duplicate(true),"active_effects":active_effects.duplicate(true),"history":history.duplicate(true),"cooldowns":cooldowns.duplicate(true),"resolved_count":resolved_count,"days_without_event":days_without_event}

func import_state(data: Dictionary) -> void:
    pending_event = data.get("pending_event", {}).duplicate(true)
    active_effects.assign(data.get("active_effects", []))
    history.assign(data.get("history", []))
    cooldowns = data.get("cooldowns", {}).duplicate(true)
    resolved_count = maxi(0, int(data.get("resolved_count", 0)))
    days_without_event = maxi(0, int(data.get("days_without_event", 0)))
    events_changed.emit()

func _build_event(event_id: String) -> Dictionary:
    var data: Dictionary = EVENTS[event_id].duplicate(true)
    data["id"] = event_id
    data["day"] = GameState.day
    return data

func _pick_event() -> String:
    var candidates: Array[String] = []
    var total_weight := 0
    for event_id in EVENTS.keys():
        if int(cooldowns.get(event_id, 0)) > 0:
            continue
        var weight := int(EVENTS[event_id].get("weight", 10))
        total_weight += weight
        for _index in range(weight):
            candidates.append(str(event_id))
    if candidates.is_empty() or total_weight <= 0:
        return ""
    return candidates.pick_random()

func _find_choice(event: Dictionary, choice_id: String) -> Dictionary:
    for choice in event.get("choices", []):
        if str(choice.get("id", "")) == choice_id:
            return choice
    return {}

func _apply_effects(effects: Dictionary) -> void:
    GameState.denarii = maxi(0, GameState.denarii + int(effects.get("denarii", 0)))
    GameState.food = maxi(0, GameState.food + int(effects.get("food", 0)))
    GameState.ore = maxi(0, GameState.ore + int(effects.get("ore", 0)))
    GameState.reputation = maxi(0, GameState.reputation + int(effects.get("reputation", 0)))
    RosterManager.intelligence_points = maxi(0, RosterManager.intelligence_points + int(effects.get("intelligence", 0)))
    RosterManager.security_score = maxi(0, RosterManager.security_score + int(effects.get("security", 0)))
    for person in RosterManager.get_people():
        person.morale = clampi(person.morale + int(effects.get("morale_all", 0)), 0, 100)
        person.loyalty = clampi(person.loyalty + int(effects.get("loyalty_all", 0)), 0, 100)
        person.training = maxi(0, person.training + int(effects.get("training_all", 0)))
    var timed = effects.get("timed", {})
    if timed is Dictionary and not timed.is_empty():
        active_effects.append(timed.duplicate(true))

func _process_active_effects() -> void:
    var expired: Array[Dictionary] = []
    for effect in active_effects:
        GameState.denarii = maxi(0, GameState.denarii + int(effect.get("daily_denarii", 0)))
        effect["days"] = int(effect.get("days", 1)) - 1
        if int(effect.get("days", 0)) <= 0:
            GameState.reputation = maxi(0, GameState.reputation + int(effect.get("reputation_on_expire", 0)))
            expired.append(effect)
    for effect in expired:
        active_effects.erase(effect)
        effect_expired.emit(effect.duplicate(true))
    if not expired.is_empty():
        events_changed.emit()

func _tick_cooldowns() -> void:
    for event_id in cooldowns.keys():
        cooldowns[event_id] = maxi(0, int(cooldowns[event_id]) - 1)

func _multiply_effect(key: String) -> float:
    var value := 1.0
    for effect in active_effects:
        value *= float(effect.get(key, 1.0))
    return value

func _count_gladiators() -> int:
    var count := 0
    for person in RosterManager.get_people():
        if person.role == "gladiator":
            count += 1
    return count
