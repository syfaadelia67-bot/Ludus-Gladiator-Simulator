extends Node

const PERSON_SCRIPT = preload("res://scripts/entities/person.gd")

func run() -> void:
    DataRepository.load_all()
    GladiatorProgressionManager._load_catalogs()
    TraitManager._load_catalog()

    _assert(DataRepository.abilities.size() == 8, "La demo debe tener ocho habilidades canónicas.")
    _assert(DataRepository.specializations.size() == 5, "Deben existir gladiador y cuatro especializaciones.")
    _assert(TraitManager.get_origin_trait_ids().size() == 8, "Deben existir ocho rasgos de origen.")
    _assert(TraitManager.get_obtainable_trait_ids().size() == 14, "Deben existir catorce rasgos obtenibles.")
    _assert(SaveManager.SAVE_VERSION == 12, "El guardado activo debe ser versión 12.")

    var previous_people := RosterManager.people.duplicate()
    var previous_records := GladiatorProgressionManager.records.duplicate(true)
    RosterManager.people.clear()
    GladiatorProgressionManager.records.clear()

    var fighter = PERSON_SCRIPT.new({
        "id":"demo_readiness_fighter",
        "name":"Prueba final",
        "role":"gladiator",
        "strength":5,
        "agility":5,
        "endurance":5,
        "intelligence":5,
        "technique":5,
        "health":50,
        "traits":["arena_lover", "protector"]
    })
    RosterManager.people.append(fighter)

    var fresh := GladiatorProgressionManager.ensure_record(fighter.id)
    _assert(int(fresh.get("level", 0)) == 1, "Un gladiador nuevo debe comenzar en nivel 1.")
    _assert(int(fresh.get("skill_points", 0)) == 1, "Un gladiador nuevo debe comenzar con un punto de habilidad.")
    _assert(Dictionary(fresh.get("abilities", {})).is_empty(), "Un gladiador nuevo no debe comenzar con habilidades aprendidas.")
    _assert(Array(fresh.get("tactical_plan", [])).is_empty(), "Un gladiador nuevo debe comenzar sin órdenes tácticas.")

    GladiatorProgressionManager.import_state({
        "records": {
            fighter.id: {
                "level":3,
                "experience":0,
                "specialization":"thraex",
                "technique_points":2,
                "techniques":["precise_strike", "iron_guard", "deep_reserves"],
                "wins":1,
                "losses":0
            }
        },
        "retired_gladiators":[]
    })
    var migrated := GladiatorProgressionManager.get_record(fighter.id)
    _assert(str(migrated.get("specialization", "")) == "dimachaerus", "thraex debe migrar a dimachaerus.")
    _assert(not migrated.has("technique_points"), "La migración debe eliminar technique_points.")
    _assert(not migrated.has("techniques"), "La migración debe eliminar techniques.")
    _assert(int(migrated.get("abilities", {}).get("precise_strike", 0)) == 1, "Golpe preciso debe migrarse.")
    _assert(int(migrated.get("abilities", {}).get("feint", 0)) == 1, "Guardia férrea debe migrar a Finta.")
    _assert(int(migrated.get("abilities", {}).get("throw_sand", 0)) == 1, "Reservas profundas debe migrar a Arrojar arena.")

    var valid_plan := [
        {"ability_id":"precise_strike", "condition":"always"},
        {"ability_id":"feint", "condition":"opening"},
        {"ability_id":"throw_sand", "condition":"target_low_energy"}
    ]
    _assert(GladiatorProgressionManager.set_tactical_plan(fighter.id, valid_plan), "El plan táctico válido debe guardarse.")
    _assert(GladiatorProgressionManager.get_tactical_plan(fighter.id).size() == 3, "El plan táctico debe conservar sus órdenes.")

    var serialized := SaveManager._serialize_person(fighter)
    _assert(serialized.has("technique"), "La ficha guardada debe incluir Técnica.")
    _assert(serialized.has("health"), "La ficha guardada debe incluir Vida.")
    _assert(serialized.has("traits"), "La ficha guardada debe incluir rasgos permanentes.")
    _assert(serialized.has("applied_trait_effects"), "La ficha guardada debe registrar efectos permanentes aplicados.")

    var old_person := SaveManager._deserialize_person({
        "id":"legacy_person",
        "name":"Legado",
        "role":"gladiator",
        "strength":5,
        "agility":5,
        "endurance":5,
        "intelligence":5,
        "traits":["arena_lover", "protector"]
    })
    _assert(old_person.technique == 5, "Una partida antigua debe recibir Técnica 5.")
    _assert(old_person.health == 50, "Una partida antigua debe recibir Vida 50.")

    var offer := MarketManager._generate_offer(0)
    _assert(offer.has("technique"), "Las ofertas deben incluir Técnica.")
    _assert(offer.has("health"), "Las ofertas deben incluir Vida.")
    _assert(Array(offer.get("traits", [])).size() == 2, "Las ofertas deben incluir dos rasgos de origen.")

    RosterManager.people = previous_people
    GladiatorProgressionManager.records = previous_records
    print("demo_readiness_integration_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("demo_readiness_integration_test: %s" % message)
        assert(condition, message)
