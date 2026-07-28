extends Node

signal rivals_changed
signal operation_completed(result: Dictionary)
signal operation_failed(reason: String)
signal rival_event(event: Dictionary)

const OPERATIONS := {
    "scout": {"name":"Explorar ludus","intel_cost":0,"denarii_cost":20,"risk":12},
    "steal_plans": {"name":"Robar planes de combate","intel_cost":12,"denarii_cost":35,"risk":28},
    "poison_supplies": {"name":"Envenenar suministros","intel_cost":20,"denarii_cost":55,"risk":42},
    "bribe_guard": {"name":"Sobornar guardia","intel_cost":8,"denarii_cost":90,"risk":22},
    "spread_rumors": {"name":"Difundir rumores","intel_cost":15,"denarii_cost":50,"risk":34}
}

var rivals: Array[Dictionary] = []
var hostility_heat: int = 0
var operations_completed: int = 0
var operations_detected: int = 0

func _ready() -> void:
    if rivals.is_empty():
        _seed_rivals()

func _seed_rivals() -> void:
    rivals = [
        {"id":"house_varro","name":"Ludus de Varro","owner":"Titus Varro","wealth":72,"security":58,"prestige":44,"relation":-15,"intel":0,"suspicion":0,"gladiator_power":61,"status":"Activo"},
        {"id":"house_sabina","name":"Casa Sabina","owner":"Sabina Drusa","wealth":55,"security":42,"prestige":63,"relation":5,"intel":0,"suspicion":0,"gladiator_power":54,"status":"Activo"},
        {"id":"house_cassian","name":"Ludus Cassianus","owner":"Lucius Cassian","wealth":84,"security":69,"prestige":76,"relation":-30,"intel":0,"suspicion":10,"gladiator_power":78,"status":"Activo"}
    ]
    rivals_changed.emit()

func get_rivals() -> Array:
    return rivals.duplicate(true)

func get_rival(rival_id: String) -> Dictionary:
    for rival in rivals:
        if str(rival.get("id", "")) == rival_id:
            return rival
    return {}

func get_operation_ids() -> Array[String]:
    var ids: Array[String] = []
    for operation_id in OPERATIONS.keys():
        ids.append(str(operation_id))
    return ids

func get_operation(operation_id: String) -> Dictionary:
    var data: Dictionary = OPERATIONS.get(operation_id, {}).duplicate(true)
    data["id"] = operation_id
    return data

func run_operation(rival_id: String, operation_id: String, agent_id: String = "") -> Dictionary:
    var rival: Dictionary = get_rival(rival_id)
    if rival.is_empty():
        operation_failed.emit("El rival seleccionado no existe.")
        return {}
    if not OPERATIONS.has(operation_id):
        operation_failed.emit("La operación seleccionada no existe.")
        return {}
    var operation: Dictionary = OPERATIONS[operation_id]
    var agent = _resolve_agent(agent_id)
    if agent == null:
        operation_failed.emit("No hay un agente disponible para la operación.")
        return {}
    if agent.injury_days > 0:
        operation_failed.emit("El agente está herido y no puede operar.")
        return {}
    var intel_cost: int = int(operation.get("intel_cost", 0))
    var denarii_cost: int = int(operation.get("denarii_cost", 0))
    if RosterManager.intelligence_points < intel_cost:
        operation_failed.emit("No hay suficientes puntos de inteligencia.")
        return {}
    if not GameState.spend_denarii(denarii_cost):
        operation_failed.emit("No hay suficientes denarios para financiar la operación.")
        return {}
    RosterManager.intelligence_points -= intel_cost

    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var skill: int = agent.intelligence * 6 + agent.agility * 3 + floori(float(agent.loyalty) / 5.0)
    if agent.traits.has("mentor"):
        skill += 6
    if agent.traits.has("freedom_seeker"):
        skill -= 5
    var defense: int = int(rival.get("security", 50)) + floori(float(int(rival.get("suspicion", 0))) / 2.0)
    var success_chance: int = clampi(45 + floori(float(skill) / 3.0) - floori(float(defense) / 2.0), 12, 92)
    var detected_chance: int = clampi(int(operation.get("risk", 20)) + floori(float(defense) / 4.0) - agent.agility * 2, 5, 85)
    var success: bool = rng.randi_range(1, 100) <= success_chance
    var detected: bool = rng.randi_range(1, 100) <= detected_chance
    var effect_text: String = ""

    if success:
        effect_text = _apply_success(rival, operation_id, rng)
        operations_completed += 1
        agent.loyalty = mini(100, agent.loyalty + 2)
    else:
        effect_text = "La operación fracasó sin producir beneficios."
        agent.fatigue = mini(100, agent.fatigue + 8)

    if detected:
        operations_detected += 1
        hostility_heat += 12
        rival["relation"] = maxi(-100, int(rival.get("relation", 0)) - 18)
        rival["suspicion"] = mini(100, int(rival.get("suspicion", 0)) + 22)
        GameState.reputation = maxi(0, GameState.reputation - 2)
        agent.morale = maxi(0, agent.morale - 5)
    else:
        rival["suspicion"] = maxi(0, int(rival.get("suspicion", 0)) - 3)

    var result: Dictionary = {
        "rival_id": rival_id,
        "rival_name": rival.get("name", rival_id),
        "operation_id": operation_id,
        "operation_name": operation.get("name", operation_id),
        "agent_id": agent.id,
        "agent_name": agent.display_name,
        "success": success,
        "detected": detected,
        "success_chance": success_chance,
        "detection_chance": detected_chance,
        "effect": effect_text
    }
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    rivals_changed.emit()
    operation_completed.emit(result)
    return result

func process_day() -> Array:
    var events: Array = []
    hostility_heat = maxi(0, hostility_heat - 1)
    for rival in rivals:
        rival["suspicion"] = maxi(0, int(rival.get("suspicion", 0)) - 1)
        if int(rival.get("relation", 0)) <= -45 and randf() < 0.10 + float(hostility_heat) / 300.0:
            var event: Dictionary = _resolve_rival_retaliation(rival)
            events.append(event)
            rival_event.emit(event)
    if not events.is_empty():
        rivals_changed.emit()
        GameState.resources_changed.emit()
    return events

func _resolve_agent(agent_id: String):
    if not agent_id.is_empty():
        var selected = RosterManager.get_person(agent_id)
        if selected != null and selected.job == "espionage":
            return selected
    var best = null
    var best_score: int = -1
    for person in RosterManager.get_people():
        if person.job != "espionage" or person.injury_days > 0:
            continue
        var score: int = person.intelligence * 2 + person.agility
        if score > best_score:
            best = person
            best_score = score
    return best

func _apply_success(rival: Dictionary, operation_id: String, rng: RandomNumberGenerator) -> String:
    match operation_id:
        "scout":
            var gained: int = rng.randi_range(8, 16)
            rival["intel"] = mini(100, int(rival.get("intel", 0)) + gained)
            RosterManager.intelligence_points += 3
            return "Se obtuvieron datos sobre seguridad, riqueza y gladiadores del rival."
        "steal_plans":
            rival["gladiator_power"] = maxi(10, int(rival.get("gladiator_power", 50)) - rng.randi_range(4, 9))
            RosterManager.intelligence_points += 8
            return "Los planes de combate robados debilitaron la preparación del rival."
        "poison_supplies":
            rival["gladiator_power"] = maxi(10, int(rival.get("gladiator_power", 50)) - rng.randi_range(8, 15))
            rival["prestige"] = maxi(0, int(rival.get("prestige", 50)) - 3)
            return "Los suministros fueron contaminados y varios combatientes rivales enfermaron."
        "bribe_guard":
            rival["security"] = maxi(10, int(rival.get("security", 50)) - rng.randi_range(7, 13))
            rival["intel"] = mini(100, int(rival.get("intel", 0)) + 12)
            return "Un guardia aceptó el soborno y reveló rutas de acceso y turnos."
        "spread_rumors":
            rival["prestige"] = maxi(0, int(rival.get("prestige", 50)) - rng.randi_range(6, 12))
            GameState.reputation += 1
            return "Los rumores dañaron el prestigio del rival entre patrocinadores y ciudadanos."
        _:
            return "La operación fue exitosa."

func _resolve_rival_retaliation(rival: Dictionary) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var security: int = RosterManager.security_score + EstateManager.get_security_bonus()
    var attack_strength: int = floori(float(int(rival.get("wealth", 50))) / 3.0) + floori(float(int(rival.get("suspicion", 0))) / 2.0)
    var blocked: bool = security + rng.randi_range(1, 30) >= attack_strength
    var description: String = ""
    var loss: int = 0
    if blocked:
        description = "Los guardias frustraron una represalia enviada por %s." % rival.get("name", "un rival")
        rival["relation"] = maxi(-100, int(rival.get("relation", 0)) - 2)
    else:
        loss = mini(GameState.denarii, rng.randi_range(35, 110))
        GameState.denarii -= loss
        GameState.food = maxi(0, GameState.food - rng.randi_range(4, 12))
        description = "%s saboteó la finca: se perdieron %d denarios y suministros." % [rival.get("name", "Un rival"), loss]
    return {
        "type":"retaliation",
        "rival_id":rival.get("id", ""),
        "rival_name":rival.get("name", "Rival"),
        "blocked":blocked,
        "loss":loss,
        "description":description
    }
