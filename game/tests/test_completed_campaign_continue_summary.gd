extends Node

func _ready() -> void:
    var inspector := FileAccess.get_file_as_string("res://scripts/core/save_compatibility_inspector.gd")
    var start_screen := FileAccess.get_file_as_string("res://scripts/ui/start_screen_controller.gd")

    assert(inspector.contains("\"campaign_over\""))
    assert(inspector.contains("\"victory\""))
    assert(inspector.contains("\"wins\""))
    assert(inspector.contains("\"losses\""))
    assert(inspector.contains("\"defeat_reason\""))

    assert(start_screen.contains("Ver resultado final"))
    assert(start_screen.contains("Campaña finalizada — %s"))
    assert(start_screen.contains("VICTORIA"))
    assert(start_screen.contains("DERROTA"))
    assert(start_screen.contains("Combates: %d victorias, %d derrotas"))
    assert(start_screen.contains("if bool(metadata.get(\"campaign_over\", false))"))
    assert(start_screen.find("if bool(metadata.get(\"campaign_over\", false))") < start_screen.find("Próximo combate: %s"))

    print("Completed campaign continue summary contract: OK")
    get_tree().quit()
