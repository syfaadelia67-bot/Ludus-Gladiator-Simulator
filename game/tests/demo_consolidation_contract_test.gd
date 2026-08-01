extends Node

func run() -> void:
    var runner_source := FileAccess.get_file_as_string("res://tests/test_runner.gd")
    var readme_source := FileAccess.get_file_as_string("res://tests/README.md")
    var save_extension_source := FileAccess.get_file_as_string("res://scripts/core/save_manager_demo.gd")
    var base_save_source := FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")
    var project_source := FileAccess.get_file_as_string("res://project.godot")

    _assert(runner_source.contains("SUITE_SUFFIX := \"/...\""), "El runner debe reconocer solicitudes de suite.")
    _assert(runner_source.contains("_discover_tests"), "El runner debe descubrir pruebas automáticamente.")
    _assert(runner_source.contains("OS.execute"), "Cada prueba de suite debe ejecutarse en un proceso aislado.")
    _assert(runner_source.contains("result.sort()"), "La suite debe ejecutarse en orden determinista.")
    _assert(readme_source.contains("--test=res://tests/..."), "La documentación debe incluir el comando de suite completa.")

    _assert(base_save_source.contains("const SAVE_VERSION := 14"), "La consolidación debe conservar compatibilidad con guardados v14.")
    _assert(save_extension_source.contains("UniqueGladiatorManager.export_state"), "El guardado debe exportar propiedad y ventanas de gladiadores únicos.")
    _assert(save_extension_source.contains("UniqueGladiatorManager.import_state"), "La carga debe restaurar el estado explícito de gladiadores únicos.")
    _assert(save_extension_source.contains("UniqueGladiatorManager.reconcile_from_world"), "Las partidas v14 anteriores deben reconstruirse de forma compatible.")
    _assert(save_extension_source.contains("MarketManager.sync_unique_offers"), "Las ofertas únicas deben sincronizarse después de cargar.")
    _assert(project_source.contains("SaveManager=\"*res://scripts/core/save_manager_demo.gd\""), "El proyecto debe usar la extensión de guardado de la demo.")

    print("demo_consolidation_contract_test: OK")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("demo_consolidation_contract_test: %s" % message)
        assert(condition, message)
