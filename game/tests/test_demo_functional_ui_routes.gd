extends Node

const DIRECT_ROUTES: Array[String] = [
	"finca",
	"barracks",
	"bestias",
	"mercado",
	"arena",
	"equipamiento",
	"personal",
	"forja",
	"campana",
	"eventos",
	"rivales",
	"economia",
	"torneos",
	"progresion",
	"personalidad",
	"relaciones",
	"transferencias",
	"historial",
]
const VALID_STATES: Array[String] = [
	"ready",
	"empty",
	"blocked",
	"error",
	"completed_read_only",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _wait_frames(8)
	_start_test_campaign()
	await _wait_frames(6)
	var first_gladiator_id := _acquire_first_gladiator()
	assert(not first_gladiator_id.is_empty())
	await _wait_frames(4)

	for route_id in DIRECT_ROUTES:
		assert(FincaHubController.open_system(route_id), "No se pudo abrir %s." % route_id)
		await _wait_frames(2)
		_assert_route_state(route_id)

	assert(
		(
			FincaHubController
			. open_gladiator_dossier(
				first_gladiator_id,
				{"system_id": "barracks", "selected_id": first_gladiator_id},
				"information",
			)
		),
		"La ficha contextual del gladiador debe ser navegable.",
	)
	await _wait_frames(2)
	_assert_route_state("gladiator_dossier")

	assert(FincaHubController.show_finca())
	await _wait_frames(1)
	print("All demo placeholder functional UI routes: OK")
	get_tree().quit(0)


func _start_test_campaign() -> void:
	StartScreenController._show_owner_creation(true)
	assert(StartScreenController.title_selector != null)
	assert(StartScreenController.origin_selector != null)
	assert(StartScreenController.origin_selector.item_count > 0)
	StartScreenController.title_selector.select(0)
	StartScreenController.origin_selector.select(0)
	StartScreenController.name_input.text = "Lucius UI"
	StartScreenController._start_new_campaign()


func _acquire_first_gladiator() -> String:
	MarketManager.refresh_market(false)
	var offers := MarketManager.get_offers()
	assert(not offers.is_empty(), "La campaña debe ofrecer candidatos iniciales.")
	var offer := offers[0] as Dictionary
	var gladiator_id := str(offer.get("unique_gladiator_id", ""))
	assert(not gladiator_id.is_empty())
	assert(MarketManager.buy_offer(str(offer.get("id", ""))))
	return gladiator_id


func _assert_route_state(route_id: String) -> void:
	assert(FincaHubController.get_current_system_id() == route_id)
	var screen := FincaHubController.get_hosted_screen(route_id)
	assert(screen != null and screen.visible, "%s debe estar visible en ScreenHost." % route_id)
	var state := DemoFunctionalUiPresenter.get_current_state()
	var state_id := str(state.get("state", ""))
	assert(VALID_STATES.has(state_id), "%s devolvió estado inválido: %s" % [route_id, state_id])
	assert(not bool(state.get("blocks_navigation", true)))

	var banner := screen.get_node_or_null("FunctionalStateBanner") as PanelContainer
	assert(banner != null, "%s debe exponer su banner funcional." % route_id)
	assert(banner.visible == (state_id != "ready"))

	var focus_owner := get_viewport().gui_get_focus_owner()
	if _has_keyboard_focus_candidate(screen):
		assert(
			focus_owner != null and screen.is_ancestor_of(focus_owner),
			"%s debe entregar foco a un control FOCUS_ALL visible." % route_id,
		)


func _has_keyboard_focus_candidate(screen: Control) -> bool:
	for candidate in screen.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.focus_mode != Control.FOCUS_ALL:
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		return true
	return false


func _wait_frames(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().process_frame
