extends Node

const FunctionalUiStatePolicyScript = preload("res://scripts/ui/demo_functional_ui_state_policy.gd")
const SCREEN_HOST_PATH := "Margin/VBox/ScreenHost"
const BANNER_NAME := "FunctionalStateBanner"

var _policy = FunctionalUiStatePolicyScript.new()
var _banner: PanelContainer
var _label: Label
var _last_state: Dictionary = {}
var _initialized := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	call_deferred("_try_initialize_for_main")


func _process(_delta: float) -> void:
	if _initialized:
		set_process(false)
		return
	_try_initialize_for_main()


func get_current_state() -> Dictionary:
	return _last_state.duplicate(true)


func get_contract() -> Dictionary:
	var contract := _policy.get_contract()
	contract["presenter"] = "DemoFunctionalUiPresenter"
	contract["state_banner"] = BANNER_NAME
	contract["state_banner_parent"] = "active_hosted_screen"
	contract["focus_baseline_enabled"] = true
	contract["focus_mode_required"] = "FOCUS_ALL"
	contract["screen_host_path"] = SCREEN_HOST_PATH
	contract["main_scene_only"] = true
	return contract


func _try_initialize_for_main() -> void:
	if _initialized or _get_main_scene() == null:
		return
	_initialized = true
	set_process(false)
	FincaHubController.system_opened.connect(_on_system_opened)
	GameState.month_advanced.connect(_on_month_advanced)
	RosterManager.roster_changed.connect(_refresh_current_state)
	MarketManager.market_changed.connect(_refresh_current_state)
	MarketManager.equipment_market_changed.connect(_refresh_current_state)
	OwnedBeastRegistry.owned_beasts_changed.connect(_refresh_current_state)
	TournamentManager.calendar_changed.connect(_refresh_current_state)
	TournamentManager.grand_tournament_changed.connect(_on_grand_tournament_changed)
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	SaveManager.load_completed.connect(_on_save_loaded)
	_refresh_current_state()


func _on_system_opened(system_id: String) -> void:
	_render_state(system_id)
	call_deferred("_focus_current_screen")


func _on_month_advanced(_month: int) -> void:
	_refresh_current_state()


func _on_grand_tournament_changed(_summary: Dictionary) -> void:
	_refresh_current_state()


func _on_locale_changed(_locale: String) -> void:
	_refresh_current_state()


func _on_save_loaded(_path: String) -> void:
	call_deferred("_refresh_current_state")


func _refresh_current_state() -> void:
	if not _initialized or not is_inside_tree():
		return
	_render_state(FincaHubController.get_current_system_id())


func _render_state(system_id: String) -> void:
	var screen := FincaHubController.get_hosted_screen(system_id)
	if screen == null:
		return
	_ensure_banner(screen)
	_last_state = _policy.evaluate(system_id)
	var state_id := str(_last_state.get("state", "error"))
	if state_id == "ready":
		_banner.visible = false
		return

	var label_key := str(_last_state.get("label_key", "UI_STATE_LABEL_ERROR"))
	var message_key := str(_last_state.get("message_key", "UI_STATE_ROUTE_ERROR"))
	var values := _last_state.get("values", {}) as Dictionary
	var label_text := LocalizationManager.translate_key(label_key)
	var message_text := LocalizationManager.translate_key(message_key, values)
	_label.text = "%s · %s" % [label_text, message_text]
	_banner.visible = true


func _ensure_banner(screen: Control) -> void:
	var existing := screen.get_node_or_null(BANNER_NAME) as PanelContainer
	if existing != null:
		_banner = existing
		_label = _banner.get_node_or_null("Margin/Message") as Label
		if _label != null:
			return

	_banner = PanelContainer.new()
	_banner.name = BANNER_NAME
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_left = 16.0
	_banner.offset_top = 12.0
	_banner.offset_right = -16.0
	_banner.offset_bottom = 76.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.z_index = 90
	screen.add_child(_banner)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(margin)

	_label = Label.new()
	_label.name = "Message"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)


func _focus_current_screen() -> void:
	if not _initialized or _start_overlay_is_visible():
		return
	var screen := FincaHubController.get_hosted_screen(FincaHubController.get_current_system_id())
	if screen == null or not screen.is_visible_in_tree():
		return
	for candidate in screen.find_children("*", "Control", true, false):
		var control := candidate as Control
		if not _is_focus_candidate(control):
			continue
		control.grab_focus()
		return


func _is_focus_candidate(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	if control.focus_mode != Control.FOCUS_ALL:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true


func _start_overlay_is_visible() -> bool:
	return (
		StartScreenController.overlay != null
		and is_instance_valid(StartScreenController.overlay)
		and StartScreenController.overlay.visible
	)


func _get_main_scene() -> Control:
	var tree := get_tree()
	if tree == null:
		return null
	var scene := tree.current_scene as Control
	if scene == null or scene.name != "Main":
		return null
	return scene


func _get_screen_host() -> Control:
	var scene := _get_main_scene()
	if scene == null:
		return null
	return scene.get_node_or_null(SCREEN_HOST_PATH) as Control
