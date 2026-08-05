extends SceneTree

# GUT runs without the game's Main scene. Scene-specific presenters otherwise
# spend frames waiting for Main.tscn and eventually emit push_error messages,
# which GUT 9.5 correctly treats as test failures. Core systems remain loaded;
# only presentation autoloads are removed for this dedicated test process.
const PRESENTATION_AUTOLOADS: Array[String] = [
    "SaveRecoveryNoticePresenter",
    "RosterMarketPresentation",
    "InitialGladiatorSelectionPresenter",
    "AllTabsUIBootstrap",
    "WeeklyCyclePresentation",
    "WeeklyClosurePresenter",
    "WeeklyCalendarPresenter",
    "WeeklyEventModalPresenter",
    "CampaignResultPresenter",
    "CompletedCampaignReadOnlyPresenter",
    "FincaHubController",
    "FincaBuildingNavigationController",
    "FincaReturnNavigationController",
    "GladiatorDossierPresenter",
    "GladiatorCareerJournalPresenter",
    "GladiatorMedicalCarePresenter",
    "GladiatorRivalryPresenter",
    "GladiatorTrainingPresenter",
    "GladiatorTacticalPlanPresenter",
    "GladiatorCareerStatePresenter",
    "ChapterObjectivePresenter",
    "RivalGladiatorActionPresenter",
    "DemoEconomyBalancePresenter",
    "StartScreenController",
    "TutorialController",
    "MainMenuReturnController"
]

func _init() -> void:
    # Some Godot startup paths create autoloads before this coroutine begins;
    # others finish adding them during the first idle frames. Remove presenters
    # both immediately and after the main loop settles.
    _disable_presentation_autoloads()

    var max_iterations := 20
    var iteration := 0
    while Engine.get_main_loop() == null and iteration < max_iterations:
        await create_timer(0.01).timeout
        iteration += 1

    if Engine.get_main_loop() == null:
        push_error("El main loop no inició a tiempo para ejecutar GUT.")
        quit(1)
        return

    for _settle_frame in range(2):
        await process_frame
        _disable_presentation_autoloads()

    var version_conversion = load("res://addons/gut/version_conversion.gd")
    if version_conversion == null:
        push_error("GUT no está instalado. Ejecutá tools/install_gut_9_5.ps1 o tools/install_gut_9_5.sh.")
        quit(1)
        return
    if version_conversion.error_if_not_all_classes_imported():
        quit(1)
        return

    var loader = load("res://addons/gut/gut_loader.gd")
    var cli := load("res://addons/gut/cli/gut_cli.gd").new() as Node
    if loader == null or cli == null:
        push_error("No se pudo crear el CLI de GUT 9.5.0.")
        quit(1)
        return
    get_root().add_child(cli)
    loader.restore_ignore_addons()
    cli.main()

func _disable_presentation_autoloads() -> void:
    var root := get_root()
    for autoload_name in PRESENTATION_AUTOLOADS:
        var presenter := root.get_node_or_null(autoload_name)
        if presenter == null:
            continue
        root.remove_child(presenter)
        presenter.free()
