extends Node

func run() -> void:
    DataRepository.load_all()
    var previous_states := UniqueGladiatorManager.states.duplicate(true)
    var previous_first := UniqueGladiatorManager.first_purchase_completed
    var previous_offers := MarketManager.offers.duplicate(true)
    var previous_rivals := RivalManager.rivals.duplicate(true)
    var previous_people := RosterManager.people.duplicate()
    var previous_week := GameState.day
    var previous_denarii := GameState.denarii

    RivalManager._seed_rivals()
    UniqueGladiatorManager.reset_for_new_campaign()
    UniqueGladiatorManager.first_purchase_completed = true
    for initial_id in ["marcus_varro", "odran", "neria"]:
        var initial_state: Dictionary = UniqueGladiatorManager.states[initial_id]
        initial_state["status"] = "rival"
        initial_state["rival_id"] = "house_varro"
        UniqueGladiatorManager.states[initial_id] = initial_state

    GameState.day = 3
    UniqueGladiatorManager.process_market_cycle(3)
    var brannoc_state := UniqueGladiatorManager.get_state("brannoc")
    _assert(str(brannoc_state.get("status", "")) == "market", "Brannoc debe aparecer en la semana 3.")
    _assert(int(brannoc_state.get("expires_week", 0)) == 5, "La oferta de Brannoc debe vencer después de tres semanas.")
    MarketManager.refresh_market(false)
    var brannoc_offer := MarketManager.get_offer("unique_brannoc")
    _assert(not brannoc_offer.is_empty(), "Brannoc debe integrarse al mercado normal.")
    _assert(int(brannoc_offer.get("weeks_remaining", 0)) == 3, "La oferta debe informar tres semanas restantes al aparecer.")

    MarketManager.refresh_market(false)
    _assert(not MarketManager.get_offer("unique_brannoc").is_empty(), "Renovar el mercado no debe eliminar ofertas únicas activas.")

    GameState.day = 6
    UniqueGladiatorManager.process_market_cycle(6)
    brannoc_state = UniqueGladiatorManager.get_state("brannoc")
    _assert(str(brannoc_state.get("status", "")) == "rival", "Una oferta vencida debe pasar a una casa rival.")
    _assert(not str(brannoc_state.get("rival_id", "")).is_empty(), "El gladiador vencido debe tener una casa rival asignada.")
    _assert(MarketManager.get_offer("unique_brannoc").is_empty(), "La oferta vencida debe desaparecer del mercado.")

    UniqueGladiatorManager.reset_for_new_campaign()
    UniqueGladiatorManager.first_purchase_completed = true
    for initial_id in ["marcus_varro", "odran", "neria"]:
        var state: Dictionary = UniqueGladiatorManager.states[initial_id]
        state["status"] = "rival"
        state["rival_id"] = "house_varro"
        UniqueGladiatorManager.states[initial_id] = state
    GameState.day = 5
    GameState.denarii = 1000
    RosterManager.people.clear()
    UniqueGladiatorManager.process_market_cycle(5)
    MarketManager.refresh_market(false)
    _assert(MarketManager.buy_offer("unique_samira_cyrene"), "Samira debe poder comprarse durante su ventana activa.")
    _assert(str(UniqueGladiatorManager.get_state("samira_cyrene").get("status", "")) == "player", "La compra debe transferir la propiedad al jugador.")
    _assert(RosterManager.get_person("samira_cyrene") != null, "La gladiadora comprada debe incorporarse al roster.")

    UniqueGladiatorManager.states = previous_states
    UniqueGladiatorManager.first_purchase_completed = previous_first
    MarketManager.offers = previous_offers
    RivalManager.rivals = previous_rivals
    RosterManager.people = previous_people
    GameState.day = previous_week
    GameState.denarii = previous_denarii
    MarketManager.market_changed.emit()
    RivalManager.rivals_changed.emit()
    RosterManager.roster_changed.emit()
    print("unique_gladiator_market_cycle_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("unique_gladiator_market_cycle_test: %s" % message)
        assert(condition, message)
