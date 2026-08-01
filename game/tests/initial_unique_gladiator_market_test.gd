extends Node

func run() -> void:
    DataRepository.load_all()

    var previous_people: Array = RosterManager.people.duplicate()
    var previous_offers: Array = MarketManager.offers.duplicate(true)
    var previous_states: Dictionary = UniqueGladiatorManager.states.duplicate(true)
    var previous_first_purchase := UniqueGladiatorManager.first_purchase_completed
    var previous_rivals: Array = RivalManager.rivals.duplicate(true)
    var previous_denarii := GameState.denarii

    RosterManager._seed_initial_roster()
    UniqueGladiatorManager.reset_for_new_campaign()
    MarketManager.refresh_market(false)
    GameState.denarii = 1000

    _assert(DataRepository.unique_gladiators.size() == 7, "La demo debe cargar siete gladiadores únicos.")
    _assert(RosterManager.get_people().size() == 3, "La campaña debe comenzar con tres personas.")
    _assert(not RosterManager.has_gladiator(), "La campaña no debe regalar un gladiador inicial.")
    for person in RosterManager.get_people():
        _assert(person.role == "slave", "Las tres personas iniciales deben ser esclavos.")

    var offers := MarketManager.get_offers()
    _assert(offers.size() == 3, "El primer mercado debe mostrar exactamente tres candidatos.")
    var candidate_ids: Array[String] = []
    for offer in offers:
        _assert(bool(offer.get("unique", false)), "Los candidatos iniciales deben ser personajes únicos.")
        candidate_ids.append(str(offer.get("unique_gladiator_id", "")))
    candidate_ids.sort()
    _assert(candidate_ids == ["marcus_varro", "neria", "odran"], "Los candidatos iniciales deben ser Marcus, Neria y Odran.")

    var chosen_offer: Dictionary = offers[0]
    var chosen_id := str(chosen_offer.get("unique_gladiator_id", ""))
    _assert(MarketManager.buy_offer(str(chosen_offer.get("id", ""))), "Debe poder comprarse el primer gladiador.")
    _assert(RosterManager.has_gladiator(), "La compra debe habilitar el primer gladiador del ludus.")
    _assert(UniqueGladiatorManager.first_purchase_completed, "La elección inicial debe quedar completada.")
    _assert(str(UniqueGladiatorManager.get_state(chosen_id).get("status", "")) == "player", "El elegido debe pertenecer al jugador.")

    var rival_count := 0
    for initial_id in ["marcus_varro", "odran", "neria"]:
        if initial_id == chosen_id:
            continue
        var state := UniqueGladiatorManager.get_state(initial_id)
        _assert(str(state.get("status", "")) == "rival", "Los candidatos no elegidos deben pasar a casas rivales.")
        _assert(not str(state.get("rival_id", "")).is_empty(), "Cada candidato rival debe tener una casa asignada.")
        rival_count += 1
    _assert(rival_count == 2, "Dos candidatos iniciales deben quedar en casas rivales.")

    RosterManager.people = previous_people
    MarketManager.offers = previous_offers
    UniqueGladiatorManager.states = previous_states
    UniqueGladiatorManager.first_purchase_completed = previous_first_purchase
    RivalManager.rivals = previous_rivals
    GameState.denarii = previous_denarii
    RosterManager.roster_changed.emit()
    MarketManager.market_changed.emit()
    RivalManager.rivals_changed.emit()
    print("initial_unique_gladiator_market_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("initial_unique_gladiator_market_test: %s" % message)
        assert(condition, message)
