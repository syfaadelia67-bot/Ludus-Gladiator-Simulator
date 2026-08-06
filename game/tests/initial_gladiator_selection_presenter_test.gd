extends Node

func run() -> void:
    var presenter := FileAccess.get_file_as_string("res://scripts/ui/initial_gladiator_selection_presenter.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    assert(presenter.contains("ELEGÍ AL PRIMER GLADIADOR DEL LUDUS"))
    assert(presenter.contains("get_initial_candidate_offers"))
    assert(presenter.contains("RETRATO\\nPENDIENTE"))
    assert(presenter.contains("Los otros dos pasarán a casas rivales"))
    assert(presenter.contains("Marcus") and presenter.contains("Odran") and presenter.contains("Neria"))
    assert(presenter.contains("MarketManager.buy_offer"))
    assert(presenter.contains('FincaHubController.get_hosted_screen("mercado")'))
    assert(presenter.contains("ContentShell/FightersView"))
    assert(presenter.contains("market_landing.visible = not choosing_first"))
    assert(presenter.contains("market_content_shell.visible = not choosing_first"))
    assert(project.contains("InitialGladiatorSelectionPresenter="))
    print("Hosted initial gladiator selection presenter contract: OK")
