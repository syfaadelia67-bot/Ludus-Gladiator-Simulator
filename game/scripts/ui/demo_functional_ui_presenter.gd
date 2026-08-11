extends Node

const FunctionalUiStatePolicyScript = preload(
	"res://scripts/ui/demo_functional_ui_state_policy.gd"
)
const SCREEN_HOST_PATH := "Margin/VBox/ScreenHost"
const BANNER_NAME := "FunctionalStateBanner"

var _policy = FunctionalUiStatePolicyScript.new()
var _banner: PanelContainer
var _label: Label
var _last_state: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	FincaHubController.system_opened.connect(_on_system_opened)
	GameState.month_advanced.connect(func(_month: int): _refresh_current_state())
	RosterManager.roster_changed.connect(_refresh_current_state)
	MarketManager.market_changed.connect(_refresh_current_state)
	MarketManager.equipment_market_changed.connect(_refresh_current_state)
	OwnedBeastRegistry.owned_beasts_changed.connect(_refresh_current_state)
	TournamentManager.calendar_changed.connect(_refresh_current_state)
	TournamentManager.grand_tournament_changed.connect(func(_summary: Dictionary): _refresh_current_state())
	LocalizationManager.locale_changed.connect(func(_locale: String): _refresh_current_state())
	SaveManager.load_completed.connect(func(_path: String): call_deferred("_refresh_current_state"))
	call_deferred("_refresh_current_state")


func get_current_state() -> Dictionary:
	return _last_state.duplicate(true)


func get_contract() -> Dictionary:
	var contract := _policy.get_contract()
	contract["presenter"] = "DemoFunctionalUiPresenter"
	contract["state_banner"] = BANNER_NAME
	contract["focus_baseline_enabled"] = true
	contract["screen_host_path"] = SCREEN_HOST_PATH
	return contract


func _on_system_opened(system_id: String) -> void:
	_render_state(system_id)
	call_deferred("_focus_current_screen")


func _refresh_current_state() -> void:
	if not is_inside_tree():
		return
	_render_state(FincaHubController.get_current_system_id())


func _render_state(system_id: String) -> void:
	var host := _get_screen_host()
	if host == null:
		return
	_ensure_banner(host)
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


func _ensure_banner(host: Control) -> void:
	if _banner != null and is_instance_valid(_banner):
		return
	var existing := host.get_node_or_null(BANNER_NAME) as PanelContainer
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
	host.add_child(_banner)

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
	if _start_overlay_is_visible():
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
	if control.focus_mode == Control.FOCUS_NONE:
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


func _get_screen_host() -> Control:
	var tree := get_tree()
	if tree == null:
		return null
	var scene := tree.current_scene as Control
	if scene == null or scene.name != "Main":
		return null
	return scene.get_node_or_null(SCREEN_HOST_PATH) as Control
