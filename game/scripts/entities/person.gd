class_name LudusPerson
extends RefCounted

var id: String
var display_name: String
var role: String = "slave"
var job: String = "idle"
var origin: String = "Unknown"
var strength: int = 5
var agility: int = 5
var endurance: int = 5
var intelligence: int = 5
var technique: int = 5
var health: int = 50
var loyalty: int = 50
var morale: int = 50
var fatigue: int = 0
var training: int = 0
var traits: Array[String] = []
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""
var equipped_shield_id: String = ""
var injury_severity: int = 0
var injury_days: int = 0
var injury_name: String = ""

func _init(data: Dictionary = {}) -> void:
    id = str(data.get("id", "person_%s" % Time.get_ticks_usec()))
    display_name = str(data.get("name", "Sin nombre"))
    role = str(data.get("role", "slave"))
    job = str(data.get("job", "idle"))
    origin = str(data.get("origin", "Unknown"))
    strength = int(data.get("strength", 5))
    agility = int(data.get("agility", 5))
    endurance = int(data.get("endurance", 5))
    intelligence = int(data.get("intelligence", 5))
    technique = int(data.get("technique", 5))
    health = maxi(1, int(data.get("health", 50)))
    loyalty = int(data.get("loyalty", 50))
    morale = int(data.get("morale", 50))
    fatigue = clampi(int(data.get("fatigue", 0)), 0, 100)
    training = maxi(0, int(data.get("training", 0)))
    traits.assign(data.get("traits", []))
    equipped_weapon_id = str(data.get("equipped_weapon_id", ""))
    equipped_armor_id = str(data.get("equipped_armor_id", ""))
    equipped_shield_id = str(data.get("equipped_shield_id", ""))
    injury_severity = clampi(int(data.get("injury_severity", 0)), 0, 3)
    injury_days = maxi(0, int(data.get("injury_days", 0)))
    injury_name = str(data.get("injury_name", ""))

func assign_job(new_job: String) -> void:
    if injury_days > 0 and new_job != "idle":
        return
    job = new_job

func process_day() -> Dictionary:
    var result := {"ore": 0, "food": 0, "security": 0, "intel": 0, "training": 0, "personality": {}}
    if injury_days > 0:
        job = "idle"
        var recovery_day_bonus := floori(float(EstateManager.get_recovery_bonus()) / 4.0)
        injury_days = maxi(0, injury_days - 1 - recovery_day_bonus)
        fatigue = maxi(0, fatigue - 10 - EstateManager.get_recovery_bonus())
        morale = mini(100, morale + 3)
        if injury_days == 0:
            injury_severity = 0
            injury_name = ""
        result.personality = PersonalityManager.process_person_day(self, result)
        return result
    match job:
        "mining":
            result.ore = maxi(1, strength + floori(float(endurance) / 2.0))
            fatigue += 8
        "security":
            result.security = maxi(1, strength + floori(float(loyalty) / 20.0))
            fatigue += 4
        "espionage":
            result.intel = maxi(1, intelligence + floori(float(agility) / 2.0))
            fatigue += 6
        "training":
            var base_gain := maxi(1, endurance + floori(float(strength) / 2.0))
            var multiplier := EstateManager.get_training_multiplier() * EventManager.get_training_multiplier()
            var gained := int(round(base_gain * multiplier))
            training += gained
            result.training = gained
            fatigue += 7
            if role == "slave" and training >= 100:
                role = "gladiator"
                job = "idle"
        _:
            fatigue = maxi(0, fatigue - 6 - EstateManager.get_recovery_bonus())
            morale = mini(100, morale + 2)
    result.personality = PersonalityManager.process_person_day(self, result)
    morale = clampi(morale - floori(float(fatigue) / 25.0), 0, 100)
    loyalty = clampi(loyalty, 0, 100)
    fatigue = clampi(fatigue, 0, 100)
    return result

func apply_growth(growth: Dictionary) -> void:
    strength += int(growth.get("strength", 0))
    agility += int(growth.get("agility", 0))
    endurance += int(growth.get("endurance", 0))
    intelligence += int(growth.get("intelligence", 0))
    technique += int(growth.get("technique", 0))
    health = maxi(1, health + int(growth.get("health", 0)))

func apply_injury(name_value: String, severity: int, days: int) -> void:
    injury_name = name_value
    injury_severity = clampi(severity, 1, 3)
    injury_days = maxi(1, days)
    job = "idle"

func is_available_for_combat() -> bool:
    return role == "gladiator" and injury_days <= 0 and fatigue < 90

func get_max_health() -> int:
    var penalty := injury_severity * 8
    return maxi(20, health + endurance * 2 - penalty)

func get_max_energy() -> int:
    var fatigue_penalty := floori(float(fatigue) / 5.0)
    var penalty := injury_severity * 6 + fatigue_penalty
    return maxi(20, 55 + endurance * 5 + agility * 3 - penalty)

func get_base_attack() -> int:
    return maxi(1, strength * 2 + agility + floori(float(technique) / 2.0) - injury_severity * 3)

func get_base_defense() -> int:
    return maxi(1, endurance + agility + floori(float(technique) / 2.0) - injury_severity * 2)

func get_injury_summary() -> String:
    if injury_days <= 0:
        return "Sin heridas"
    return "%s — %d día(s)" % [injury_name, injury_days]

func summary() -> String:
    return "%s | %s | trabajo: %s | lealtad: %d | moral: %d | fatiga: %d | %s" % [
        display_name, role, job, loyalty, morale, fatigue, get_injury_summary()
    ]