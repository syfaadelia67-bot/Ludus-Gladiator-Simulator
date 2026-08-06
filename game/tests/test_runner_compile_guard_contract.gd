extends Node

func run() -> void:
    var runner_text: String = FileAccess.get_file_as_string("res://tests/test_runner.gd")
    assert(not runner_text.is_empty(), "Debe poder leerse el runner de pruebas.")
    assert(runner_text.contains("test_script.can_instantiate()"), "El runner debe comprobar que el script compiló antes de llamar new().")
    assert(runner_text.contains("Could not compile or instantiate test script"), "El fallo de compilación debe producir un diagnóstico único y legible.")
    print("Test runner compile guard contract: OK")
