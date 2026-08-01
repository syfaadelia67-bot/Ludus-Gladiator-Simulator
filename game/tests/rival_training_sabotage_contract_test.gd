extends Node

func run() -> void:
    var action_source := FileAccess.get_file_as_string("res://scripts/systems/rival_gladiator_action_controller.gd")
    var progression_source := FileAccess.get_file_as_string("res://scripts/systems/rival_unique_gladiator_controller.gd")

    _assert(action_source.contains("training_disrupted_until"), "El sabotaje debe registrar hasta cuándo se interrumpe el entrenamiento rival.")
    _assert(progression_source.contains("int(profile.get(\"training_disrupted_until\", 0)) >= week"), "El progreso semanal debe respetar la interrupción del entrenamiento.")
    _assert(progression_source.contains("profile[\"last_progress_week\"] = week"), "Una semana saboteada debe marcarse como procesada para impedir dobles intentos.")
    _assert(progression_source.contains("func _sanitize_profile"), "Los perfiles rivales antiguos deben sanear los nuevos campos.")
    _assert(progression_source.contains("\"loyalty\": clampi"), "Los perfiles nuevos deben conservar lealtad propia.")

    print("rival_training_sabotage_contract_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("rival_training_sabotage_contract_test: %s" % message)
        assert(condition, message)
