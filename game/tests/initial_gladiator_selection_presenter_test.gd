extends Node

func run() -> void:
    var presenter_path := "res://scripts/ui/initial_gladiator_selection_presenter.gd"
    var project_path := "res://project.godot"
    var presenter := _read_text(presenter_path)
    var project := _read_text(project_path)

    _assert(not presenter.is_empty(), "Debe existir el presentador de selección inicial.")
    _assert("ELEGÍ AL PRIMER GLADIADOR DEL LUDUS" in presenter, "La elección debe tener un encabezado propio.")
    _assert("get_initial_candidate_offers" in presenter, "Las tarjetas deben usar los tres candidatos únicos.")
    _assert("RETRATO\\nPENDIENTE" in presenter, "Las tarjetas deben reservar el espacio de retrato sin requerir assets finales.")
    _assert("Los otros dos serán comprados por casas rivales" in presenter, "La consecuencia de la elección debe explicarse antes de comprar.")
    _assert("Marcus" in presenter and "Odran" in presenter and "Neria" in presenter, "Las consecuencias deben contemplar a los tres candidatos.")
    _assert("MarketManager.buy_offer" in presenter, "La presentación debe reutilizar la compra real del mercado.")
    _assert("market_list.visible = not choosing_first" in presenter, "El mercado normal debe ocultarse durante la elección inicial.")
    _assert("buy_button.visible = not choosing_first" in presenter, "El botón genérico no debe competir con las tarjetas iniciales.")
    _assert("InitialGladiatorSelectionPresenter=" in project, "El presentador debe estar registrado como autoload.")
    _assert(project.find("RosterMarketPresentation=") < project.find("InitialGladiatorSelectionPresenter="), "La selección especial debe registrarse después de la presentación normal de mercado.")

    print("initial_gladiator_selection_presenter_test: OK")

func _read_text(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    var text := file.get_as_text()
    file.close()
    return text

func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("initial_gladiator_selection_presenter_test: %s" % message)
        assert(condition, message)
