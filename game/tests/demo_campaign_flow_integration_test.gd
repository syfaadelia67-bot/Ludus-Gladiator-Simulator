extends Node

const REQUIRED_SYSTEMS := [
	"barracks",
	"mercado",
	"equipamiento",
	"personal",
	"forja",
	"eventos",
	"campana",
	"arena",
]
const HOSTED_SYSTEMS := [
	"finca",
	"barracks",
	"mercado",
	"equipamiento",
	"personal",
	"forja",
	"eventos",
	"campana",
	"arena",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _wait_frames(8)
	_assert_main_startup_shell()
	assert(
		StartScreenController.overlay != null and StartScreenController.overlay.visible,
		"La pantalla de inicio debe mostrarse al abrir Main."
	)

	StartScreenController._show_owner_creation()
	await _wait_frames(1)
	assert(
		StartScreenController.title_selector != null,
		"La creación de campaña debe ofrecer Dominus o Domina."
	)
	assert(
		StartScreenController.origin_selector != null
		and StartScreenController.origin_selector.item_count > 0,
		"La creación de campaña debe ofrecer orígenes."
	)
	StartScreenController.title_selector.select(1)
	StartScreenController.origin_selector.select(0)
	StartScreenController.name_input.text = "Aurelia"
	StartScreenController._start_new_campaign()

	await _wait_frames(8)
	assert(
		not StartScreenController.overlay.visible,
		"Una campaña nueva debe cerrar la pantalla de inicio."
	)
	assert(
		LudusOwnerManager.get_title_label() == "Domina",
		"La campaña debe conservar la elección Domina."
	)
	assert(
		FincaHubController.get_current_system_id() == "mercado",
		"El onboarding debe abrir Mercado hasta contratar al primer gladiador."
	)
	_assert_navigation_state("mercado")
	assert(
		TutorialController.panel == null or not TutorialController.panel.visible,
		"El tutorial guiado debe esperar a que termine la elección inicial."
	)

	var initial_offers := UniqueGladiatorManager.get_initial_candidate_offers()
	assert(not initial_offers.is_empty(), "La campaña debe ofrecer candidatos iniciales.")
	var initial_offer: Dictionary = initial_offers[0]
	assert(
		MarketManager.buy_offer(str(initial_offer.get("id", ""))),
		"La primera contratación debe usar el flujo real del Mercado."
	)
	await _wait_frames(4)
	assert(
		UniqueGladiatorManager.first_purchase_completed,
		"La primera contratación debe quedar registrada."
	)
	assert(RosterManager.has_gladiator(), "La contratación debe incorporar un gladiador al roster.")
	assert(
		TutorialController.panel != null and TutorialController.panel.visible,
		"Tras la primera contratación debe comenzar el tutorial mensual."
	)

	assert(FincaHubController.show_finca(), "El onboarding debe permitir volver a Finca.")
	await _wait_frames(1)
	_assert_navigation_state("finca")

	for system_id in REQUIRED_SYSTEMS:
		assert(FincaHubController.open_system(system_id), "La Finca debe navegar a %s." % system_id)
		await _wait_frames(1)
		assert(
			FincaHubController.get_current_system_id() == system_id,
			"La navegación debe abrir %s." % system_id
		)
		_assert_navigation_state(system_id)
		assert(
			FincaHubController.show_finca(),
			"Cada sistema debe permitir regresar al hub de Finca."
		)
		await _wait_frames(1)
		assert(
			FincaHubController.get_current_system_id() == "finca",
			"Regresar desde %s debe restaurar Finca." % system_id
		)
		_assert_navigation_state("finca")

	var finca_screen := FincaHubController.get_hosted_screen("finca")
	assert(finca_screen != null, "La Finca debe existir dentro de ScreenHost.")
	var forge_hotspot := (
		finca_screen.get_node_or_null("Center/WorldPanel/WorldMargin/WorldArea/Hotspot_forge")
		as Button
	)
	var enter_button := (
		finca_screen.get_node_or_null("Center/BuildingDetailsPanel/Margin/Scroll/Details/Enter")
		as Button
	)
	assert(forge_hotspot != null, "La Finca debe exponer la Forja como hotspot.")
	assert(enter_button != null, "La Finca debe exponer el acceso contextual del edificio.")
	forge_hotspot.pressed.emit()
	await _wait_frames(1)
	enter_button.pressed.emit()
	await _wait_frames(1)
	assert(
		FincaHubController.get_current_system_id() == "forja",
		"Entrar desde el hotspot de Forja debe abrir su sistema."
	)
	_assert_navigation_state("forja")
	assert(FincaHubController.show_finca(), "El retorno desde una instalación debe volver a Finca.")
	await _wait_frames(1)
	_assert_navigation_state("finca")

	var main_scene := get_tree().current_scene
	var close_month := (
		main_scene.get_node_or_null("UnifiedHudShell/TopHUD/Margin/Row/AdvanceWeek") as Button
	)
	assert(close_month != null, "El HUD unificado debe exponer el botón Cerrar mes.")
	assert(
		WeeklyClosurePresenter.advance_button == close_month,
		"El cierre mensual debe estar conectado al botón visible del HUD."
	)
	var starting_month := GameState.get_month()

	close_month.pressed.emit()
	await _wait_frames(2)
	assert(
		WeeklyClosurePresenter.overlay != null and WeeklyClosurePresenter.overlay.visible,
		"Cerrar mes debe abrir el resumen previo."
	)

	var monthly_summary := WeeklyPlanningController.get_summary()
	assert(
		not bool(monthly_summary.get("event_pending", false)),
		"Una campaña recién creada no debe bloquear el Mes I con un evento pendiente."
	)
	assert(
		not bool(monthly_summary.get("fight_pending", false)),
		"El Mes I de gestión no debe inventar un combate obligatorio."
	)
	assert(
		bool(monthly_summary.get("can_close", false)),
		"El Mes I debe poder cerrarse cuando sus blockers canónicos están resueltos."
	)
	WeeklyClosurePresenter._confirm()
	await _wait_frames(2)
	assert(
		GameState.get_month() == starting_month + 1,
		"Confirmar el cierre debe avanzar exactamente un mes."
	)

	assert(SaveManager.save_game(), "La campaña debe guardarse antes de volver al menú.")
	MainMenuReturnController._save_and_return()
	await _wait_frames(2)
	assert(
		StartScreenController.overlay.visible,
		"Guardar y menú debe restaurar la pantalla de inicio."
	)
	assert(
		not StartScreenController.continue_button.disabled,
		"Una campaña guardada debe habilitar Continuar campaña."
	)
	StartScreenController._continue_campaign()
	await _wait_frames(8)
	_assert_main_startup_shell()
	assert(
		not StartScreenController.overlay.visible,
		"Continuar campaña debe cerrar la pantalla de inicio."
	)
	assert(
		FincaHubController.get_current_system_id() == "finca",
		"Continuar campaña debe volver a Finca."
	)
	_assert_navigation_state("finca")

	print("Real Main monthly onboarding, hosted flow and save/continue smoke test: OK")
	get_tree().quit(0)


func _assert_main_startup_shell() -> void:
	var main_scene := get_tree().current_scene
	assert(
		main_scene != null and main_scene.name == "Main",
		"El proyecto debe arrancar sobre la escena Main real."
	)
	assert(main_scene.get_script() == null, "Main debe permanecer como shell sin controlador propio.")

	var host := main_scene.get_node_or_null("Margin/VBox/ScreenHost") as Control
	var hud := main_scene.get_node_or_null("UnifiedHudShell") as Control
	assert(host != null and host.is_inside_tree(), "Main debe montar un ScreenHost operativo.")
	assert(hud != null and hud.is_inside_tree(), "El bootstrap debe montar el HUD unificado.")
	assert(main_scene.get_node_or_null("Margin/VBox/Tabs") == null)
	assert(main_scene.get_node_or_null("Margin/VBox/Title") == null)
	assert(main_scene.get_node_or_null("Margin/VBox/Resources") == null)
	assert(main_scene.get_node_or_null("Margin/VBox/TopButtons") == null)

	var hud_row := (
		main_scene.get_node_or_null("UnifiedHudShell/TopHUD/Margin/Row") as HBoxContainer
	)
	var close_month := (
		main_scene.get_node_or_null("UnifiedHudShell/TopHUD/Margin/Row/AdvanceWeek") as Button
	)
	var return_menu := (
		main_scene.get_node_or_null("UnifiedHudShell/TopHUD/Margin/Row/ReturnToMainMenu")
		as Button
	)
	assert(hud_row != null, "El HUD real debe exponer su fila superior.")
	assert(close_month != null and close_month.visible, "Cerrar mes debe existir en el HUD visible.")
	assert(
		return_menu != null and return_menu.get_parent() == hud_row,
		"Guardar y menú debe montarse en el HUD visible."
	)


func _assert_navigation_state(system_id: String) -> void:
	var main_scene := get_tree().current_scene
	assert(main_scene != null and main_scene.name == "Main")
	var host := main_scene.get_node_or_null("Margin/VBox/ScreenHost") as Control
	var tabs := main_scene.get_node_or_null("Margin/VBox/Tabs") as TabContainer
	assert(host != null, "Main debe mantener un ScreenHost activo.")
	assert(tabs == null, "Main no debe conservar pestañas heredadas.")
	assert(HOSTED_SYSTEMS.has(system_id), "%s debe ser un sistema hospedado." % system_id)

	var active_screen := FincaHubController.get_hosted_screen(system_id)
	assert(active_screen != null, "%s debe estar instanciado en ScreenHost." % system_id)
	assert(active_screen.get_parent() == host, "%s debe ser hijo de ScreenHost." % system_id)
	assert(active_screen.visible, "%s debe ser la pantalla hospedada visible." % system_id)
	assert(active_screen.mouse_filter == Control.MOUSE_FILTER_PASS)
	assert(host.visible and host.mouse_filter == Control.MOUSE_FILTER_PASS)
	for child in host.get_children():
		if child is Control:
			var hosted_control := child as Control
			assert(hosted_control.visible == (hosted_control == active_screen))


func _wait_frames(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().process_frame
