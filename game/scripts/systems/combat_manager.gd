extends Node

signal combat_finished(result: Dictionary)
signal combat_failed(reason: String)

const TACTICS := {
    "balanced": "Equilibrada",
    "aggressive": "Agresiva",
    "defensive": "Defensiva",
    "careful": "Cuidadosa"
}

var last_result: Dictionary = {}

func get_tactic_ids() -> Array[String]:
    var result: Array[String] = []
    for tactic_id in TACTICS.keys():
        result.append(str(tactic_id))
    return result

func get_tactic_name(tactic_id: String) -> String:
    return str(TACTICS.get(tactic_id, tactic_id.capitalize()))

func simulate_duel(gladiator_id: String, tactic: String = "balanced") -> Dictionary:
    var fighter = RosterManager.get_person(gladiator_id)
    if fighter == null or fighter.role != "gladiator":
        combat_failed.emit("Seleccioná un gladiador válido.")
        return {}
    if not TACTICS.has(tactic):
        combat_failed.emit("La táctica seleccionada no existe.")
        return {}

    var enemy := _generate_enemy(fighter)
    var player := _build_combatant(fighter, tactic)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var combat_log: Array[String] = []
    var round := 0

    combat_log.append("%s entra a la arena con táctica %s." % [fighter.display_name, get_tactic_name(tactic)])
    while player.health > 0 and enemy.health > 0 and round < 30:
        round += 1
        combat_log.append("--- Ronda %d ---" % round)
        _perform_attack(player, enemy, rng, combat_log)
        if enemy.health <= 0:
            break
        _perform_attack(enemy, player, rng, combat_log)
        player.energy = mini(player.max_energy, player.energy + 5)
        enemy.energy = mini(enemy.max_energy, enemy.energy + 5)

    var victory := enemy.health <= 0 and player.health > 0
    var reward := 0
    var reputation := 0
    if victory:
        reward = 70 + enemy.attack * 3
        reputation = 2 + enemy.defense / 8
        GameState.denarii += reward
        GameState.reputation += reputation
        fighter.morale = mini(100, fighter.morale + 8)
        combat_log.append("%s obtiene la victoria." % fighter.display_name)
    else:
        fighter.morale = maxi(0, fighter.morale - 10)
        fighter.fatigue = mini(100, fighter.fatigue + 15)
        combat_log.append("%s pierde el combate." % fighter.display_name)

    last_result = {
        "victory": victory,
        "rounds": round,
        "fighter": fighter.display_name,
        "fighter_id": fighter.id,
        "enemy": enemy.name,
        "tactic": tactic,
        "player_health": maxi(0, player.health),
        "player_max_health": player.max_health,
        "player_energy": maxi(0, player.energy),
        "player_max_energy": player.max_energy,
        "enemy_health": maxi(0, enemy.health),
        "enemy_max_health": enemy.max_health,
        "enemy_energy": maxi(0, enemy.energy),
        "enemy_max_energy": enemy.max_energy,
        "player_attack": player.attack,
        "player_defense": player.defense,
        "enemy_attack": enemy.attack,
        "enemy_defense": enemy.defense,
        "reward": reward,
        "reputation": reputation,
        "log": combat_log
    }
    GameState.resources_changed.emit()
    RosterManager.roster_changed.emit()
    combat_finished.emit(last_result)
    return last_result

func _build_combatant(person, tactic: String) -> Dictionary:
    var equipment := EquipmentManager.get_equipped_stats(person)
    var attack := person.get_base_attack() + int(equipment.get("power", 0))
    var defense := person.get_base_defense() + int(equipment.get("defense", 0))
    var accuracy := 55 + person.agility * 3
    var energy_cost := 12
    match tactic:
        "aggressive":
            attack = int(attack * 1.20)
            defense = int(defense * 0.85)
            energy_cost = 16
        "defensive":
            defense = int(defense * 1.25)
            attack = int(attack * 0.90)
            energy_cost = 9
        "careful":
            accuracy += 12
            attack = int(attack * 0.92)
            energy_cost = 10
    return {
        "name": person.display_name,
        "health": person.get_max_health(),
        "max_health": person.get_max_health(),
        "energy": person.get_max_energy(),
        "max_energy": person.get_max_energy(),
        "attack": attack,
        "defense": defense,
        "accuracy": accuracy,
        "energy_cost": energy_cost
    }

func _generate_enemy(person) -> Dictionary:
    var tier := maxi(1, (person.strength + person.agility + person.endurance) / 8)
    return {
        "name": "Gladiador rival nivel %d" % tier,
        "health": 75 + tier * 20,
        "max_health": 75 + tier * 20,
        "energy": 70 + tier * 8,
        "max_energy": 70 + tier * 8,
        "attack": 15 + tier * 5,
        "defense": 8 + tier * 4,
        "accuracy": 58 + tier * 3,
        "energy_cost": 12
    }

func _perform_attack(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator, combat_log: Array[String]) -> void:
    if attacker.energy < attacker.energy_cost:
        attacker.energy = mini(attacker.max_energy, attacker.energy + 12)
        combat_log.append("%s recupera energía." % attacker.name)
        return
    attacker.energy -= attacker.energy_cost
    if rng.randi_range(1, 100) > int(attacker.accuracy):
        combat_log.append("%s falla el ataque." % attacker.name)
        return
    var variance := rng.randi_range(-3, 4)
    var damage := maxi(1, int(attacker.attack) + variance - int(defender.defense) / 2)
    defender.health -= damage
    combat_log.append("%s causa %d de daño a %s." % [attacker.name, damage, defender.name])