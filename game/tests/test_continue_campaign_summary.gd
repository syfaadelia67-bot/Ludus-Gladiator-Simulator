extends Node

func _ready() -> void:
    var source := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")

    assert(source.contains("func _format_save_summary"))
    assert(source.contains("owner_name"))
    assert(source.contains("owner_title"))
    assert(source.contains("Semana %d de 16"))
    assert(source.contains("Capítulo %d"))
    assert(source.contains("Próximo combate"))
    assert(source.contains("Un ludus en ruinas"))
    assert(source.contains("Sangre y reputación"))
    assert(source.contains("El nombre del ludus"))
    assert(source.contains("Torneo oficial de la arena"))
    assert(source.contains("Cacería de bestias del anfiteatro"))
    assert(source.contains("Combate clandestino del bajo mundo"))
    assert(source.contains("Exhibición semanal del ludus"))

    print("Continue campaign summary contract: OK")
    get_tree().quit()
