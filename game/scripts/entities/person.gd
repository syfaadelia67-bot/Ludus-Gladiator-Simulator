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
var loyalty: int = 50
var morale: int = 50
var fatigue: int = 0
var training: int = 0
var traits: Array[String] = []
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""
var equipped_shield_id: String = ""

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
    loyalty = int(data.get("loyalty", 50))
    morale = int(data.get("morale", 50))
    traits.assign(data.get("traits", []))

func assign_job(new_job: String) -> void:
    job = new_job

func process_day() -> Dictionary:
    var result := {"ore": 0, "food": 0, "security": 0, "intel": 0, "training": 0}
    match job:
        "mining":
            result.ore = maxi(1, strength + endurance / 2)
            fatigue += 8
        "security":
            result.security = maxi(1, strength + loyalty / 20)
            fatigue += 4
        "espionage":
            result.intel = maxi(1, intelligence + agility / 2)
            fatigue += 6
        "training":
            var base_gain := maxi(1, endurance + strength / 2)
            var gained := int(round(base_gain * EstateManager.get_training_multiplier()))
            training += gained
            result.training = gained
            fatigue += 7
            if role == "slave" and training >= 100:
                role = "gladiator"
                job = "idle"
        _:
            fatigue = maxi(0, fatigue - 6 - EstateManager.get_recovery_bonus())
            morale = mini(100, morale + 2)
    morale = clampi(morale - fatigue / 25, 0, 100)
    return result

func get_max_health() -> int:
    return 70 + endurance * 8 + strength * 2

func get_max_energy() -> int:
    return 55 + endurance * 5 + agility * 3

func get_base_attack() -> int:
    return strength * 2 + agility

func get_base_defense() -> int:
    return endurance + agility

func summary() -> String:
    return "%s | %s | trabajo: %s | lealtad: %d | moral: %d | fatiga: %d" % [
        display_name, role, job, loyalty, morale, fatigue
    ]
