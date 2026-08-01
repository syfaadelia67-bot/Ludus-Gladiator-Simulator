extends Node

func run() -> void:
    DataRepository.load_all()
    var previous_rivals: Array = RivalManager.rivals.duplicate(true)
    var previous_states: Dictionary = UniqueGladiatorManager.states.duplicate(true)
    var previous_first_purchase := UniqueGladiatorManager.first_purchase_completed
    var previous_day := GameState.day

    RivalManager._seed_rivals()
    UniqueGladiatorManager.reset_for_new_campaign()
    UniqueGladiatorManager.first_purchase_completed = true
    GameState.day = 3

    UniqueGladiatorManager._move_to_rival("brannoc", "house_varro", 3)
    RivalUniqueGladiatorController._ensure_all_profiles()

    var initial := RivalUniqueGladiatorController.get_profile("brannoc")
    _assert(not initial.is_empty(), "Brannoc debe tener un perfil dentro de la casa rival.")
    _assert(str(initial.get("rival_id", "")) == "house_varro", "El perfil debe conservar la casa rival.")
    _assert(int(initial.get("level", 0)) == 1, "El rival único debe comenzar en nivel 1.")

    RivalUniqueGladiatorController._on_week_advanced(4)
    var progressed := RivalUniqueGladiatorController.get_profile("brannoc")
    _assert(int(progressed.get("last_progress_week", 0)) == 4, "El perfil debe registrar la semana procesada.")
    _assert(int(progressed.get("experience", 0)) > 0, "El gladiador rival debe ganar experiencia semanal.")

    var opponent_a := RivalUniqueGladiatorController.get_opponent_for_week(4, "official")
    var opponent_b := RivalUniqueGladiatorController.get_opponent_for_week(4, "official")
    _assert(str(opponent_a.get("gladiator_id", "")) == "brannoc", "El rival único debe estar disponible como oponente.")
    _assert(opponent_a == opponent_b, "La selección del oponente debe ser determinista para la misma semana.")
    _assert(str(opponent_a.get("rival_name", "")).contains("Varro"), "El oponente debe exponer el nombre de su casa.")
    _assert(RivalUniqueGladiatorController.get_opponent_for_week(4, "beast_hunt").is_empty(), "Las cacerías de bestias no deben usar gladiadores rivales.")

    RivalUniqueGladiatorController.register_combat_result("brannoc", true)
    var defeated := RivalUniqueGladiatorController.get_profile("brannoc")
    _assert(int(defeated.get("losses", 0)) == 1, "La victoria del jugador debe registrar una derrota rival.")
    _assert(int(defeated.get("arena_appearances", 0)) == 1, "La aparición en Arena debe registrarse.")

    RivalUniqueGladiatorController.register_combat_result("brannoc", false)
    var victorious := RivalUniqueGladiatorController.get_profile("brannoc")
    _assert(int(victorious.get("wins", 0)) == 1, "La derrota del jugador debe registrar una victoria rival.")

    RivalManager.rivals = previous_rivals
    UniqueGladiatorManager.states = previous_states
    UniqueGladiatorManager.first_purchase_completed = previous_first_purchase
    GameState.day = previous_day
    RivalManager.rivals_changed.emit()
    print("rival_unique_gladiator_progression_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("rival_unique_gladiator_progression_test: %s" % message)
        assert(condition, message)
